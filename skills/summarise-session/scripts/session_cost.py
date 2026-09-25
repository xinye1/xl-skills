#!/usr/bin/env python3
"""Equivalent API cost for a Claude Code session transcript.

Sums per-turn token usage from a session's .jsonl transcript (and any
subagent transcripts under <session-id>/subagents/) and prices it at the
API list prices in references/prices.json. This is what the session would
have cost as pay-per-token API calls -- not a bill, since interactive
sessions run on a subscription.

One API response is written to the transcript as one line per content
block, each repeating the identical full `message.usage` object; this
script dedupes by `message.id` so usage is counted once per turn.

Transcripts are also not the whole story: some billed calls (notably in
subagent transcripts, which are written mid-stream) never land a final,
fully-counted line, and Claude Code itself writes a `cost-state` record
with its own `totalCostUSD` into the main transcript when a session ends
(/clear, exit, resume-switch). When that record exists and the session
has genuinely ended (no assistant turn follows it), it is the authoritative
total for this session -- more reliable than summing the transcripts -- and
the Total row uses it, with the transcript-priced per-agent rows relabelled
as lower bounds and the gap surfaced as its own row. For a live session, or
one resumed past its last cost-state, there is no authoritative total yet;
the Total row is the transcript sum, marked as a floor.

Usage:
    session_cost.py [<session-id-or-path.jsonl>] [--json] [--prices PATH]

    <session-id-or-path.jsonl> can be:
      - a full/relative path to a transcript .jsonl file, or
      - a bare session id, in which case the project directory is
        inferred from the current working directory (the project slug
        is cwd with "/" replaced by "-"), matching how Claude Code lays
        out ~/.claude/projects/<slug>/<session-id>.jsonl.

    Omit it to default to the current session: the newest *.jsonl by
    mtime directly under that same inferred project directory (this is
    normally the live session invoking this script). The chosen path is
    printed to stderr so stdout stays a paste-ready table.
"""
import argparse
import json
import os
import re
import sys
from collections import defaultdict
from math import floor, log10
from pathlib import Path

DATE_SUFFIX_RE = re.compile(r"^(?P<base>.+)-\d{8}$")


# --------------------------------------------------------------------------
# Transcript loading
# --------------------------------------------------------------------------

def load_turns(path):
    """Read one transcript .jsonl file and return a list of per-turn usage
    dicts, deduped by message.id.

    A message split across N content-block lines repeats the same
    message.id and the same full usage object on all N lines -- counting
    every line would multiply usage by the block count, so only one line
    per id is kept. Which line to keep differs by transcript kind: main
    transcripts write one complete line per message.id, but *subagent*
    transcripts are written mid-stream -- several lines can share an id,
    with the early ones carrying `stop_reason: null` and a partial
    `usage.output_tokens`, and only the final line (when present) carrying
    the full count. Input/cache fields are set at stream start and don't
    grow, so only output_tokens actually varies across an id's lines.
    Keeping the *first* line therefore undercounts output for subagents
    (seen as low as ~8% of the true figure); instead, per message.id, keep
    the line with the largest output_tokens, ties going to the later line.
    """
    turns = []
    if not path.is_file():
        return turns
    best_by_id = {}
    order = []
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return turns
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(rec, dict) or rec.get("type") != "assistant":
            continue
        msg = rec.get("message")
        if not isinstance(msg, dict):
            continue
        mid = msg.get("id")
        if not mid:
            continue
        model = msg.get("model")
        if not model or model == "<synthetic>":
            continue
        usage = msg.get("usage")
        if not isinstance(usage, dict):
            continue
        cc = usage.get("cache_creation")
        if not isinstance(cc, dict):
            cc = {}
        speed = usage.get("speed") or "standard"
        if speed not in ("standard", "fast"):
            speed = "standard"
        output = usage.get("output_tokens", 0) or 0
        turn = {
            "model": model,
            "speed": speed,
            "input": usage.get("input_tokens", 0) or 0,
            "output": output,
            "cache_write": usage.get("cache_creation_input_tokens", 0) or 0,
            "cc_5m": cc.get("ephemeral_5m_input_tokens", 0) or 0,
            "cc_1h": cc.get("ephemeral_1h_input_tokens", 0) or 0,
            "cache_read": usage.get("cache_read_input_tokens", 0) or 0,
        }
        prev = best_by_id.get(mid)
        if prev is None:
            order.append(mid)
            best_by_id[mid] = turn
        elif output >= prev["output"]:
            best_by_id[mid] = turn
    turns = [best_by_id[mid] for mid in order]
    return turns


def aggregate_turns(turns):
    """Aggregate a list of per-turn usage dicts into agg[model][speed] ->
    token totals. Cache-write tokens with no 5m/1h split (older
    transcripts, where cache_creation_input_tokens > the ephemeral_* sum)
    have their unsplit remainder folded into the 5m bucket for pricing
    (5-minute TTL is the default) and counted in "unsplit_remainder" so
    callers can footnote it. Returns (agg, unsplit_remainder_total)."""
    agg = defaultdict(lambda: defaultdict(lambda: defaultdict(int)))
    unsplit_total = 0
    for t in turns:
        b = agg[t["model"]][t["speed"]]
        b["input"] += t["input"]
        b["output"] += t["output"]
        b["cache_write"] += t["cache_write"]
        b["cache_read"] += t["cache_read"]
        b["cc_1h"] += t["cc_1h"]
        remainder = t["cache_write"] - t["cc_5m"] - t["cc_1h"]
        if remainder > 0:
            b["cc_5m"] += t["cc_5m"] + remainder
            unsplit_total += remainder
        else:
            b["cc_5m"] += t["cc_5m"]
        b["messages"] += 1
    return agg, unsplit_total


# --------------------------------------------------------------------------
# Claude Code's own cost meter (cost-state records)
# --------------------------------------------------------------------------

def find_cost_state(path):
    """Scan the main transcript for the last `cost-state` record Claude
    Code writes on session end (/clear, exit, resume-switch).

    Returns (cost_state, ended, stale_time):
      - cost_state: the last cost-state record (dict), or None if the
        transcript has none.
      - ended: True only if a cost-state exists AND no `assistant` line
        follows it -- i.e. the session genuinely closed with nothing
        billed afterwards, so cost_state["totalCostUSD"] is authoritative.
      - stale_time: when a cost-state exists but assistant turns follow it
        (a resumed session -- the meter is stale), the timestamp of the
        transcript line immediately before the cost-state record, as the
        closest available wall-clock proxy (cost-state records carry no
        timestamp of their own, only a `startTime` for the tracking
        window). None when there's no cost-state, or it isn't stale.
    """
    if not path.is_file():
        return None, False, None
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return None, False, None

    records = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(rec, dict):
            records.append(rec)

    last_cs_pos = None
    last_cs = None
    for pos, rec in enumerate(records):
        if rec.get("type") == "cost-state":
            last_cs_pos = pos
            last_cs = rec

    if last_cs is None:
        return None, False, None

    assistant_after = any(
        r.get("type") == "assistant" for r in records[last_cs_pos + 1:]
    )
    ended = not assistant_after

    stale_time = None
    if not ended:
        for r in reversed(records[:last_cs_pos]):
            ts = r.get("timestamp")
            if isinstance(ts, str):
                stale_time = ts
                break

    return last_cs, ended, stale_time


# --------------------------------------------------------------------------
# Pricing
# --------------------------------------------------------------------------

def load_prices(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def resolve_price_entry(model_id, prices):
    """Exact model-ID lookup; on miss, strip a trailing -YYYYMMDD date
    suffix and retry once. Never family/substring matches (claude-opus-5
    must never match claude-opus-5-5). Returns (entry_or_None,
    matched_key_or_None)."""
    models = prices.get("models", {})
    if model_id in models:
        return models[model_id], model_id
    m = DATE_SUFFIX_RE.match(model_id)
    if m:
        base = m.group("base")
        if base in models:
            return models[base], base
    return None, None


FIELD_TO_TOKEN_KEY = {
    "input": "input",
    "output": "output",
    "cache_write_5m": "cc_5m",
    "cache_write_1h": "cc_1h",
    "cache_read": "cache_read",
}


def price_agent(agg, prices):
    """Price one agent's full agg[model][speed] usage. Returns a dict with
    summed token totals, a cost (float, or None if any model/speed slice
    in this agent couldn't be priced), the reasons it couldn't be priced,
    and any unconfirmed price fields that were actually exercised."""
    totals = defaultdict(int)
    cost = 0.0
    unpriced_reasons = []
    unconfirmed_used = set()
    fast_mode_seen = False
    models_seen = set()

    for model_id in sorted(agg.keys()):
        models_seen.add(model_id)
        entry, _matched_key = resolve_price_entry(model_id, prices)
        for speed, tok in agg[model_id].items():
            totals["input"] += tok["input"]
            totals["output"] += tok["output"]
            totals["cache_write"] += tok["cache_write"]
            totals["cache_read"] += tok["cache_read"]

            if entry is None:
                unpriced_reasons.append(f"unknown model {model_id}")
                continue

            if speed == "fast":
                fast_mode_seen = True
                fm = entry.get("fast_mode")
                if fm is None:
                    unpriced_reasons.append(
                        f"fast-mode price not documented for {model_id}"
                    )
                    continue
                rate_in, rate_out = fm["input"], fm["output"]
                if fm.get("unconfirmed"):
                    unconfirmed_used.add(f"{model_id} fast_mode")
            else:
                rate_in, rate_out = entry["input"], entry["output"]

            # Cache write/read pricing is not fast-mode-specific in the
            # source (only input/output carry a documented fast premium),
            # so cache tokens are priced at the model's standard cache
            # rates regardless of speed.
            slice_cost = (
                tok["input"] * rate_in
                + tok["output"] * rate_out
                + tok["cc_5m"] * entry["cache_write_5m"]
                + tok["cc_1h"] * entry["cache_write_1h"]
                + tok["cache_read"] * entry["cache_read"]
            ) / 1_000_000
            cost += slice_cost

            for field in entry.get("unconfirmed") or []:
                tok_key = FIELD_TO_TOKEN_KEY.get(field)
                if tok_key and tok.get(tok_key, 0) > 0:
                    unconfirmed_used.add(f"{model_id} {field}")

    return {
        "models": sorted(models_seen),
        "input": totals["input"],
        "output": totals["output"],
        "cache_write": totals["cache_write"],
        "cache_read": totals["cache_read"],
        "cost": None if unpriced_reasons else cost,
        "unpriced_reasons": unpriced_reasons,
        "unconfirmed_used": unconfirmed_used,
        "fast_mode_seen": fast_mode_seen,
    }


# --------------------------------------------------------------------------
# Formatting
# --------------------------------------------------------------------------

def human_tokens(n):
    n = int(n)
    if n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}k"
    return str(n)


def round_sig(x, sig=2):
    if x == 0:
        return 0.0
    exp = floor(log10(abs(x)))
    return round(x, sig - exp - 1)


def format_cost(x):
    """Round to 2 significant figures, formatted as e.g. ~$1.9, ~$0.034."""
    if x is None:
        return None
    r = round_sig(x, 2)
    if r == 0:
        return "~$0"
    exp = floor(log10(abs(r)))
    decimals = max(2 - exp - 1, 0)
    return f"~${r:.{decimals}f}"


# --------------------------------------------------------------------------
# Session / subagent discovery
# --------------------------------------------------------------------------

def project_dir_for_cwd():
    """The ~/.claude/projects/<slug> directory Claude Code uses for the
    current working directory (slug = cwd with '/' replaced by '-')."""
    slug = str(Path.cwd()).replace(os.sep, "-")
    return Path.home() / ".claude" / "projects" / slug


def resolve_session_path(arg):
    """Accept either a transcript path or a bare session id (project dir
    inferred from cwd, slug = cwd with '/' replaced by '-')."""
    if arg.endswith(".jsonl") or os.sep in arg or arg.startswith("~"):
        return Path(arg).expanduser()
    return project_dir_for_cwd() / f"{arg}.jsonl"


def find_newest_session(project_dir):
    """Return the most-recently-modified top-level *.jsonl transcript in
    project_dir (by mtime), or None if there isn't one. Subagent
    transcripts live one directory deeper (<session-id>/subagents/), so a
    non-recursive glob here only ever sees top-level session transcripts.
    This is normally the live session invoking this script."""
    candidates = [p for p in project_dir.glob("*.jsonl") if p.is_file()]
    if not candidates:
        return None
    return max(candidates, key=lambda p: p.stat().st_mtime)


def find_subagents(session_path):
    """Return a list of (label, agg, unsplit_total) for each subagent
    transcript sitting next to this session, ordered by the .meta.json's
    mtime (an approximation of invocation order) when available, else by
    filename."""
    session_dir = session_path.parent / session_path.name[: -len(".jsonl")]
    subagents_dir = session_dir / "subagents"
    if not subagents_dir.is_dir():
        return []

    entries = []
    for jsonl_path in subagents_dir.glob("agent-*.jsonl"):
        agent_id = jsonl_path.name[len("agent-"):-len(".jsonl")]
        meta_path = subagents_dir / f"agent-{agent_id}.meta.json"
        meta = {}
        sort_key = jsonl_path.name
        if meta_path.is_file():
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                meta = {}
            try:
                sort_key = meta_path.stat().st_mtime
            except OSError:
                pass
        entries.append((sort_key, agent_id, jsonl_path, meta))

    # mtime (float) sorts fine against itself; fall back entries (str)
    # only occur if meta.json was unreadable, so keep them stably last
    # among themselves by filename.
    entries.sort(key=lambda e: (isinstance(e[0], str), e[0]))

    out = []
    for _sort_key, agent_id, jsonl_path, meta in entries:
        description = meta.get("description")
        agent_type = meta.get("agentType")
        if description and agent_type:
            label = f"{description} ({agent_type})"
        elif description:
            label = description
        elif agent_type:
            label = agent_type
        else:
            label = f"subagent {agent_id}"
        turns = load_turns(jsonl_path)
        agg, unsplit = aggregate_turns(turns)
        out.append((label, agg, unsplit))
    return out


# --------------------------------------------------------------------------
# Report assembly
# --------------------------------------------------------------------------

def build_report(session_path, prices):
    rows = []

    main_turns = load_turns(session_path)
    main_agg, main_unsplit = aggregate_turns(main_turns)
    rows.append(("main chat", price_agent(main_agg, prices), main_unsplit))

    for label, agg, unsplit in find_subagents(session_path):
        rows.append((label, price_agent(agg, prices), unsplit))

    transcript_total_cost = sum(r[1]["cost"] for r in rows if r[1]["cost"] is not None)
    excludes_unpriced = any(r[1]["cost"] is None for r in rows)

    cost_state, ended, stale_time = find_cost_state(session_path)
    claude_code_total = None
    if cost_state is not None:
        claude_code_total = cost_state.get("totalCostUSD")

    unattributed = None
    if claude_code_total is not None:
        unattributed = round(claude_code_total - transcript_total_cost, 10)

    # The Total row uses Claude Code's own meter only when the session has
    # genuinely ended and it doesn't undercut the transcript sum (a
    # negative gap means the meter and the transcripts disagree in the
    # other direction -- e.g. price drift -- so the transcript sum is the
    # safer number to show, with a footnote explaining why).
    if ended and claude_code_total is not None and unattributed is not None and unattributed >= -0.0005:
        total_source = "claude_code"
    else:
        total_source = "transcripts"

    total = {
        "input": sum(r[1]["input"] for r in rows),
        "output": sum(r[1]["output"] for r in rows),
        "cache_write": sum(r[1]["cache_write"] for r in rows),
        "cache_read": sum(r[1]["cache_read"] for r in rows),
        "cost": claude_code_total if total_source == "claude_code" else transcript_total_cost,
        "excludes_unpriced": excludes_unpriced,
        "claude_code_total": claude_code_total,
        "transcript_total": transcript_total_cost,
        "unattributed": unattributed,
        "total_source": total_source,
        "ended": ended,
        "stale_time": stale_time,
    }

    unconfirmed_all = set()
    unpriced_all = []
    unsplit_used = main_unsplit > 0
    fast_mode_used = False
    for label, priced, unsplit in rows:
        unconfirmed_all |= priced["unconfirmed_used"]
        unpriced_all.extend(priced["unpriced_reasons"])
        if unsplit > 0:
            unsplit_used = True
        if priced["fast_mode_seen"]:
            fast_mode_used = True

    footnotes = []
    footnotes.append(
        f"Equivalent API cost at list prices as of {prices.get('as_of', '?')} "
        f"({prices.get('source', 'see references/prices.json')}); not a bill."
    )

    if total_source == "claude_code":
        footnotes.append(
            "Total is Claude Code's own totalCostUSD for this session (its cost-state "
            "record, written on session end); the per-agent and main-chat rows above are "
            "transcript-priced floors -- some billed calls never reach any transcript, "
            "which is what the 'not attributed to an agent' row captures."
        )
    elif cost_state is not None and claude_code_total is not None and unattributed is not None and unattributed < -0.0005:
        footnotes.append(
            f"Claude Code's own meter reports {format_cost(claude_code_total)} for this "
            f"session, less than the transcript-priced sum ({format_cost(transcript_total_cost)}); "
            "showing the transcript total in the Total row instead."
        )
    else:
        note = (
            "No authoritative total yet: Claude Code only saves its own cost-state "
            "when a session ends (/clear, exit, resume-switch), and "
        )
        if cost_state is None:
            note += "this transcript has none -- it's still live."
        else:
            note += (
                "the last one here is stale (assistant turns follow it, from a "
                "resumed session)"
                + (f", recorded around {stale_time}" if stale_time else "")
                + "."
            )
        note += (
            " The Total row above is the transcript sum, a floor, and so is every "
            "row in the table -- for the live "
            "session's true total, check the status bar's $ figure. Transcripts "
            "typically run 15-35% under it when subagents are used, 0-8% under "
            "without."
        )
        footnotes.append(note)

    if unconfirmed_all:
        footnotes.append(
            "Uses unconfirmed prices (pending confirmation at launch) for: "
            + ", ".join(sorted(unconfirmed_all)) + "."
        )
    if unpriced_all:
        # de-dupe while preserving order
        seen = set()
        reasons = [r for r in unpriced_all if not (r in seen or seen.add(r))]
        footnotes.append(
            "Total excludes rows that could not be priced: " + "; ".join(reasons) + "."
        )
    if unsplit_used:
        footnotes.append(
            "Some cache-write tokens predate the 5m/1h split "
            "(cache_creation_input_tokens with no matching ephemeral_5m/1h breakdown) "
            "and were priced at the 5-minute rate."
        )
    if fast_mode_used:
        footnotes.append(
            "Includes turns run in fast mode (usage.speed == \"fast\"); "
            "cache write/read tokens on those turns are priced at the model's "
            "standard cache rates (no fast-mode cache pricing is documented)."
        )

    return rows, total, footnotes


# --------------------------------------------------------------------------
# Output
# --------------------------------------------------------------------------

def render_markdown(rows, total, footnotes):
    lines = [
        "| Agent | Model(s) | Input | Output | Cache write | Cache read | Equivalent API cost |",
        "|---|---|---|---|---|---|---|",
    ]
    for label, priced, _unsplit in rows:
        models_display = ", ".join(priced["models"]) if priced["models"] else "–"
        if priced["cost"] is None:
            cost_display = "not priced (" + "; ".join(priced["unpriced_reasons"]) + ")"
        else:
            cost_display = format_cost(priced["cost"])
        lines.append(
            f"| {label} | {models_display} | {human_tokens(priced['input'])} | "
            f"{human_tokens(priced['output'])} | {human_tokens(priced['cache_write'])} | "
            f"{human_tokens(priced['cache_read'])} | {cost_display} |"
        )

    if total["total_source"] == "claude_code" and total["unattributed"] is not None:
        # Claude Code's meter prices every call, so the gap also holds the cost
        # of any row this script couldn't price; say so rather than overstate
        # the calls that never reached a transcript.
        gap_label = "not attributed to an agent"
        if total["excludes_unpriced"]:
            gap_label += " (incl. unpriced rows)"
        lines.append(
            f"| {gap_label} | – | – | – | – | – | "
            f"{format_cost(total['unattributed'])} |"
        )

    if total["total_source"] == "claude_code":
        total_cost_display = f"{format_cost(total['cost'])} (Claude Code's own meter)"
    else:
        total_cost_display = f"≥ {format_cost(total['cost'])} (transcripts)"
        if total["excludes_unpriced"]:
            total_cost_display += " (excl. unpriced rows)"
    lines.append(
        f"| **Total** |  | {human_tokens(total['input'])} | {human_tokens(total['output'])} | "
        f"{human_tokens(total['cache_write'])} | {human_tokens(total['cache_read'])} | "
        f"{total_cost_display} |"
    )

    out = "\n".join(lines) + "\n"
    if footnotes:
        out += "\n" + "\n".join(f"- {f}" for f in footnotes) + "\n"
    return out


def render_json(session_path, rows, total, footnotes, prices):
    return json.dumps({
        "session": str(session_path),
        "as_of": prices.get("as_of"),
        "source": prices.get("source"),
        "rows": [
            {
                "agent": label,
                "models": priced["models"],
                "input": priced["input"],
                "output": priced["output"],
                "cache_write": priced["cache_write"],
                "cache_read": priced["cache_read"],
                "cost": priced["cost"],
                "unpriced_reasons": priced["unpriced_reasons"],
                "unconfirmed_prices_used": sorted(priced["unconfirmed_used"]),
            }
            for label, priced, _unsplit in rows
        ],
        "total": total,
        "claude_code_total": total["claude_code_total"],
        "transcript_total": total["transcript_total"],
        "unattributed": total["unattributed"],
        "total_source": total["total_source"],
        "footnotes": footnotes,
    }, indent=2)


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Equivalent API cost for a Claude Code session transcript."
    )
    parser.add_argument(
        "session",
        nargs="?",
        default=None,
        help=(
            "Transcript path, or a bare session id (project dir inferred "
            "from cwd). Omit to default to the newest session in the "
            "current project directory."
        ),
    )
    parser.add_argument(
        "--json", action="store_true", help="Emit raw per-row numbers as JSON"
    )
    parser.add_argument(
        "--prices",
        default=None,
        help="Path to prices.json (default: references/prices.json next to this script)",
    )
    args = parser.parse_args(argv)

    if args.session:
        session_path = resolve_session_path(args.session)
    else:
        project_dir = project_dir_for_cwd()
        session_path = find_newest_session(project_dir)
        if session_path is None:
            print(f"error: no transcripts found in {project_dir}", file=sys.stderr)
            return 1
        print(f"session: {session_path.name} (newest in {project_dir}, none given)", file=sys.stderr)

    if not session_path.is_file():
        print(f"error: transcript not found: {session_path}", file=sys.stderr)
        return 1

    prices_path = (
        Path(args.prices).expanduser()
        if args.prices
        else Path(__file__).resolve().parent.parent / "references" / "prices.json"
    )
    try:
        prices = load_prices(prices_path)
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: could not load prices from {prices_path}: {e}", file=sys.stderr)
        return 1

    rows, total, footnotes = build_report(session_path, prices)

    if args.json:
        print(render_json(session_path, rows, total, footnotes, prices))
    else:
        print(render_markdown(rows, total, footnotes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
