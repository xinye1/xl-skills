# xl-skills docs index

A map of the decisions, reports and method documents for the skills in this repo. Each skill's own behaviour lives in `skills/<name>/SKILL.md`; this folder records how and why the skills changed.

These docs start on 2026-11-13. For earlier changes, see the git log and the merged PRs.

## Methodology

- [Refinement log](methodology/refinement-log.md): dated entries, one per skill refinement. Each records what prompted it, the evidence, what changed, what was considered and rejected, and what the pass caught.

## Reports

- [reports/2026-11-17-pstack-overlap.md](reports/2026-11-17-pstack-overlap.md): pstack skills that resemble xl-skills ones, with pros and cons of each pair and what was wired in, adapted or left alone.

## Upstream

- [upstream.md](upstream.md): skills from elsewhere that these skills use (poteto's pstack, installed as a plugin and pinned), how they are started, and the rule for depending on them. Also: this repo is upstream of the Concord delivery kit (delivery-guardrail).

## Decisions

| Date | Skill | Decision | Where |
|---|---|---|---|
| 2026-11-19 | ship | pstack is pinned to a reviewed commit instead of auto-updating. A session-start check says what's new upstream and asks before moving the pin (`pstack-pin.sh`). xl-skills itself stays unpinned | [refinement log](methodology/refinement-log.md#2026-11-19--pstack-is-pinned-a-new-session-says-whats-new-and-asks-before-moving-the-pin), [upstream.md](upstream.md) |
| 2026-11-17 | ship, handover, execute-phased-plan, summarise-session, adversarial-review | Wire in pstack where it fills a gap and leave the overlapping xl-skills skills in charge. Decision log (`show-me-your-work`) for multi-phase and unattended runs; claimed numbers checked at the verification gate; `blast-radius` offered at review; `reflect`'s filters and `interrogate`'s proof-by-run taken in xl-skills' own words; `ketchup` and `sharpen` not wired | [report](reports/2026-11-17-pstack-overlap.md), [refinement log](methodology/refinement-log.md#2026-11-17--wiring-in-the-rest-of-pstack-where-it-fills-a-gap) |
| 2026-11-17 | ship, summarise-session | poteto's pstack is installed as a plugin (auto-update, pinned from 2026-11-19) instead of copied. `ship` gains a verification gate (Step 3b), where a fresh agent drives the change in the real app, using pstack's `create-verification-skill`. `summarise-session` offers pstack's `correct` for repeated corrections. xl-skills holds the all-project version; delivery-guardrail adapts it | [refinement log, 2026-11-17](methodology/refinement-log.md#2026-11-17--potetos-pstack-as-a-plugin-ship-gains-a-verification-gate), [upstream.md](upstream.md) |
| 2026-11-13 | handover, pickup | Size the orchestrator to the phase's shape (`sonnet` for well-scoped, `opus` by default, `fable` for the hardest) and recommend an effort level; subagents escalate by verification, then effort, then tier | [refinement log, 2026-11-13](methodology/refinement-log.md#2026-11-13--handover-follows-anthropics-model-selection-guidance) |
