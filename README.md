# xl-skills

Xinye's personal Claude Code skills.

## Layout

```
xl-skills/
├── skills/
│   └── <name>/SKILL.md
└── dist/              # packaged .skill artifacts (gitignored)
```

Each skill is a directory under `skills/` containing a `SKILL.md` with YAML frontmatter (`name`, `description`) and Markdown instructions. Optional subdirectories per skill: `scripts/`, `references/`, `assets/`.

## Installing locally

Symlink this repo's `skills/` directory to `~/.claude/skills` once. Because it's a single folder-level link (not per-skill links), any skill you add, rename, or edit in the repo shows up immediately — no relinking needed.

> Note: `~/.claude/skills` must not already exist as a real directory. If it does, move or remove it first (back up anything you want to keep).

**macOS / Linux** (run from the repo root):

```bash
ln -s "$(pwd)/skills" ~/.claude/skills
```

**Windows** (Command Prompt, run from the repo root):

```cmd
mklink /J "%USERPROFILE%\.claude\skills" "%CD%\skills"
```

`/J` creates a directory junction, which works without admin access or Developer Mode.

**Windows** (PowerShell, run from the repo root):

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.claude\skills" -Target "$PWD\skills"
```

## Packaging a skill for sharing

From the skill-creator plugin directory (run from this repo's root):

```bash
# The version segment in the path may vary — check with:
# ls ~/.claude/plugins/cache/claude-plugins-official/skill-creator/
SKILL_CREATOR=~/.claude/plugins/cache/claude-plugins-official/skill-creator/*/skills/skill-creator
REPO_SKILL="$(pwd)/skills/<name>"
(cd "$SKILL_CREATOR" && python -m scripts.package_skill "$REPO_SKILL")
```

Or set an explicit path to this repo:

```bash
REPO=/path/to/xl-skills
SKILL_CREATOR=~/.claude/plugins/cache/claude-plugins-official/skill-creator/*/skills/skill-creator
(cd "$SKILL_CREATOR" && python -m scripts.package_skill "$REPO/skills/<name>")
```

Packaged `.skill` files land in `dist/` (gitignored).

## To learn more

- [Claude Code skills documentation](https://code.claude.com/docs/en/skills) — the official guide to creating, configuring, and sharing skills
- [skill-creator plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) — the official plugin used to generate and package skills, and the tool used to build the skills in this repo

## Token management

Claude re-reads its **entire accumulated context on every tool call**. So a session's cost grows with the *square* of its length, not linearly: an agent that makes 600 tool calls costs roughly 4x one that makes 300, for twice the work. Nothing in the tooling caps this — the 1M-token context window carries no price premium, so a long-running agent will happily pay a million tokens a call to return twenty.

Measured across one heavy day of these skills' own workflows: 1.7bn tokens, of which **635 calls ran above 500k of context and returned under 100 tokens each — 27% of the day's spend for near-zero yield**. Separately, two subagents were killed by a usage limit 300+ calls in, discarding context that had already been bought.

Three practices follow. Each is carried by a specific skill element rather than left to good intentions:

**1. Keep each unit of work inside one working context.**

| Level | Where it lives |
|---|---|
| Chat | [`execute-phased-plan`](skills/execute-phased-plan/SKILL.md) cuts at phase boundaries; [`handover`](skills/handover/SKILL.md) carries state across, so no one chat accumulates a whole plan |
| Task | The task-sizing contract in [`execution-model.md`](skills/handover/references/execution-model.md) — one coherent deliverable, ~50–150 tool calls, split anything that would grind on the same large artifact for hours |
| Detection | [`summarise-session`](skills/summarise-session/SKILL.md) names oversized tasks in its orchestration read — outlier tool-call counts, or late calls carrying a large context for near-empty replies |

**2. Let the default model tier do its job.** [`execution-model.md`](skills/handover/references/execution-model.md) sizes each subagent's model to its task — `sonnet` by default, escalating only for genuine ambiguity or blast radius. That rule was always there; what is new beside it is the measured consequence (1,944 `sonnet` task-subagent calls ~$77 in a day, against 2,900 `opus` calls ~$734). The exception is deliberate: [`adversarial-review`](skills/adversarial-review/SKILL.md) and [`nuclear-code-review`](skills/nuclear-code-review/SKILL.md) mandate opus-or-above, because a weak reviewer nodding along is worse than no review.

**3. Make long work survivable.** [`execution-model.md`](skills/handover/references/execution-model.md) requires any subagent expected to run past ~30 minutes to checkpoint progress to a named durable file. A killed agent's context is unrecoverable and already paid for — checkpointing turns a lost run into lost minutes.

Both execution-model variants carry all three, since they are inlined verbatim into every handover prompt and so travel into chats that never load a skill.

> Checking your own numbers: `python3 ~/.claude/token-audit.py [YYYY-MM-DD]` reconstructs per-day and per-subagent spend from local transcripts. Not part of this repo; it lives beside the memory that documents the incident above.

## Current skills

| Skill | What it does |
|---|---|
| [ship](skills/ship/SKILL.md) | End-to-end code shipping: group commits → branch → test → push → PR → CI → merge → local cleanup, with mandatory independent coderabbit review whose timing follows the repo's CI coupling (so CI runs once). Designed to compose cleanly with the superpowers dev-loop skills (picks up where `finishing-a-development-branch` leaves off). |
| [execute-phased-plan](skills/execute-phased-plan/SKILL.md) | Chat-level pacing for long multi-phase plans: execute one phase, verify exit criteria, stop at the boundary, emit a self-contained handover prompt for a fresh chat. Keeps each chat's context tight around one phase. |
| [handover](skills/handover/SKILL.md) | Save a self-contained handover prompt to `~/.claude/handovers/<repo>/`, re-read it from disk to prove the save, and print a short receipt with the next steps (`/clear` first, then `/model` only when the chat isn't already on the recommended model, then `/pickup`; plus a `claude --model` line for picking up after a reboot), so a multi-phase plan continues in a fresh chat without drift and nothing is copied by hand. A deliberate, visible alternative to `/compact`: the old chat stays resumable, and the file survives a reboot on its own. Works end-of-phase or mid-phase; the emitted prompt instructs the next chat to orchestrate subagents per task and run overall validation itself. Prompt style is keyed to the recommended orchestrator model: prescriptive template for `sonnet`, goal-directed (goals + why + constraints, no procedure) for `opus` (5+) / `fable`. The orchestration text is single-sourced in [references/execution-model.md](skills/handover/references/execution-model.md) (with a constraints-form variant, [execution-model-goal-directed.md](skills/handover/references/execution-model-goal-directed.md)) and shared with `execute-phased-plan`. |
| [pickup](skills/pickup/SKILL.md) | The receiving half of `handover`. `/pickup` in a fresh chat lists the repo's waiting handovers (you pick when several are waiting; `all` or search text widens the search), stops before loading if this chat is on a weaker model than the handover wants (the receipt with the `/model` step is gone after `/clear`), reads the chosen one in full, flags staleness (commits since it was written) and path drift (another worktree or machine), archives it to `picked-up/` (never deleted, can be reloaded), prints a receipt, and starts on it as the chat's brief. |
| [summarise-session](skills/summarise-session/SKILL.md) | The backward-looking bookend to `handover`: an honest end-of-session retrospective *for the human* (prose in the chat, not a prompt). Surfaces the meta-layer git can't show — what was discovered, what went sideways, how the subagents/orchestration actually performed (timing, tokens, quality, and equivalent API cost at list prices, priced by its `scripts/session_cost.py`), gotchas to carry forward, and candidate follow-ups (issues, memories, plan edits) surfaced for the user to action rather than auto-filed. Honest evidence only — "not captured" over fabricated figures. Composes with `handover` as the sense-making pass that feeds the persistence pass. |
| [boil-the-ocean](skills/boil-the-ocean/SKILL.md) | Implementation completeness standard (after Gary Tan): push past "good enough" toward "holy shit, that's done." Five-question done-check, five anti-patterns to kill, and an explicit reconciliation with the system prompt's "no scope creep" rule — completeness *within* the asked-for scope, not unbounded polish. |
| [adversarial-review](skills/adversarial-review/SKILL.md) | Independent adversarial review of plans and specs by a **cold advanced-model subagent** (opus default, fable for high-blast-radius artifacts). Counters the authoring session's commitment bias: the reviewer reads only the artifact file + repo (never the transcript, never the authoring rationale) and contests assumptions/contradictions/feasibility — antagonistic toward the claims, constructive toward the work: every finding carries evidence and a resolution condition, and returns with a verdict + ranked findings. Findings are triaged with evidence under `receiving-code-review` discipline; one re-review round max. Plans/specs only — code correctness goes to the code-review skills, code structure to `nuclear-code-review`. |
| [nuclear-code-review](skills/nuclear-code-review/SKILL.md) | The code-side structural mirror of `adversarial-review`: a **cold advanced-model subagent** (same ≥-authoring-model rule) reviews a committed diff against an unusually harsh maintainability bar — rubric adapted from Cursor's `thermo-nuclear-code-quality-review`. Its defining demand is the **code-judo move**: restructurings that delete whole branches/helpers/layers rather than rearranging them — "the solution that makes the code feel inevitable in hindsight". Presumptive blockers (1k-line file explosions, spaghetti growth, hollow abstractions, boundary rot, architectural drift) put the burden of proof on the diff; every finding needs file:line evidence and a resolution condition. Gates only — accepted restructurings go back through the dev loop or `simplify`. Consent-gated, and orthogonal to the correctness reviewers, which still run. |
| [grill-into-design](skills/grill-into-design/SKILL.md) | Socratic grilling for non-trivial design decisions before any code lands. Hybrid of `superpowers:brainstorming` (hard-gate, spec-doc terminus, `writing-plans` handoff) and Matt Pocock's grill tactics (recommended-answer pattern, branch-walking, inline glossary, ADR-on-3-criteria gate, 120K-token budget, `[needs-prototype]` escape hatch). Terminates in a structured spec doc, not a chat transcript. |
| [deepen-architecture](skills/deepen-architecture/SKILL.md) | The proactive, whole-codebase counterpart to `nuclear-code-review`: answers "what should we restructure?" when there is no diff yet. Scopes by git-log hot spots, sends read-only explorers to report friction as evidence (they observe, the orchestrator judges), then clusters it into **deepening opportunities** — shallow modules turned deep — filtered by the **deletion test** (delete it: does complexity vanish, or reappear across N callers?) and classified by dependency category so the testing shape and any port fall out of the analysis. Ships as a visual Artifact: before/after diagrams per candidate, strength badges, top recommendation. Stops there and asks which one; the pick hands off to `grill-into-design`. The deep-module vocabulary (module, interface, depth, seam, adapter, leverage, locality) is folded into [references/deep-modules.md](skills/deepen-architecture/references/deep-modules.md) so the skill stands alone. Adapted from Matt Pocock's `improve-codebase-architecture`. |
| [status-report](skills/status-report/SKILL.md) † | Supervising long-running work (background jobs, training runs, backfills, CI, deploys) and reporting it honestly: a fixed report format (timestamp, per-workstream state + delta + ETA, blockers first, next checkpoint) backed by a supervision rig set up at launch (sentinels, background-task tracking, scheduled cadence, re-arming monitors after restarts). Evidence from live checks, never recollection. |
| [elii](skills/elii/SKILL.md) † | "Explain Like I'm an Intern" — the explanation register calibrated to Xinye: expert in ML/stats/product, not fluent in infra/networking/software-internals/finance jargon. Per concept: plain one-liner → where it shows up in *our* system with real values → why it matters for the decision at hand. **Fires proactively before any turn that asks for a decision, sign-off or go/no-go**, rewriting the ask as a numbered decision brief (what needs deciding · what you need to know · options with what happens · my lean) — a month of transcripts showed 6 of 11 manual "elii" triggers were bounces off exactly such asks, each costing a full extra turn at session context size. Also proactive for root-cause narratives, recovery summaries and machine-side effects. |
| [ops-relay](skills/ops-relay/SKILL.md) † | Driving hands-on work through the user on machines Claude can't reach (fresh VPS, phone over adb, Windows/WSL host, cloud consoles): one verified step at a time — single copy-pasteable block, expected output stated, host labelled, step ledger kept — then write the proven path back into the runbook. |
| [git-triage](skills/git-triage/SKILL.md) † | Resolving dirty working trees by classification, not bulk action: diagnose the source of every untracked-file group, sort into track / ignore / delete / keep-local, fix `.gitignore` at pattern level (a 10k-file explosion is one missing pattern), never `git add -A`, never delete a parallel worktree's files. |
| [cross-session-brief](skills/cross-session-brief/SKILL.md) † | Coordinating parallel peer sessions with the user as message bus: self-contained briefs with a scope fence and peer-reachable paths (worktree-aware), reconciling — not blindly obeying — peer updates, preferring durable channels (memory, pushed branches) over chat relay, and a proper close-out when the other session finishes. Sideways companion to the forward-looking `handover`. |
| [review-focus](skills/review-focus/SKILL.md) † | A reviewer's guide attached to any long artifact presented for sign-off: the ranked judgement calls (with recommendation and cost-of-wrong), the assumptions made on the user's behalf, an explicit safe-to-skim map, and numbered points that fit the "1 yes, 2 agree, 3 ELI5" reply style. Product-owner altitude, not line-editing. |
| [storm-research](skills/storm-research/SKILL.md) | The heavyweight research skill (quick lookups don't need it — answer those directly). Multi-perspective research that ends in something an AI can *build* from. Merges Stanford **STORM** (perspective discovery → grounded writer↔expert conversations → outline-first article), **3-vote adversarial verification**, and the five-lens/contradiction-map approach. Two human gates (perspectives, outline); emits a long-form Markdown article **plus a machine-actionable Implementation Brief**, with an optional human-facing layer (`+eli5`): an **ELI5 plain-language version** plus an **interactive, self-contained HTML page** (Simple⇄Full toggle, confidence meters, dark mode). See [references/comparison.md](skills/storm-research/references/comparison.md) for the three-way lineage. |

**†** Auto-discovered by mining a month of past sessions for recurring cross-project patterns, and still *refine-through-use* drafts — they haven't been hardened through repeated deliberate use the way the unmarked skills have. Every unmarked skill was deliberately authored for a purpose I set out to serve. This tag records provenance and current maturity for pruning/refinement decisions only; it does **not** affect how or when a skill is invoked (invocation is trigger-matching on the description, blind to pedigree), and it deliberately lives here in the catalogue rather than inside the skill bodies.
