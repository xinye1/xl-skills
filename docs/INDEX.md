# xl-skills docs index

A map of the decisions, reports and method documents for the skills in this repo. Each skill's own behaviour lives in `skills/<name>/SKILL.md`; this folder records how and why the skills changed.

These docs start on 2026-11-13. For earlier changes, see the git log and the merged PRs.

## Methodology

- [Refinement log](methodology/refinement-log.md): dated entries, one per skill refinement. Each records what prompted it, the evidence, what changed, what was considered and rejected, and what the pass caught.

## Upstream

- [upstream.md](upstream.md): skills from elsewhere that these skills use (poteto's pstack, installed as a plugin), how they are started, and the rule for depending on them. Also: this repo is upstream of the Concord delivery kit (delivery-guardrail).

## Decisions

| Date | Skill | Decision | Where |
|---|---|---|---|
| 2026-11-17 | ship, summarise-session | poteto's pstack is installed as a plugin (auto-update) instead of copied. `ship` gains a verification gate (Step 3b), where a fresh agent drives the change in the real app, using pstack's `create-verification-skill`. `summarise-session` offers pstack's `correct` for repeated corrections. xl-skills holds the all-project version; delivery-guardrail adapts it | [refinement log, 2026-11-17](methodology/refinement-log.md#2026-11-17--potetos-pstack-as-a-plugin-ship-gains-a-verification-gate), [upstream.md](upstream.md) |
| 2026-11-13 | handover, pickup | Size the orchestrator to the phase's shape (`sonnet` for well-scoped, `opus` by default, `fable` for the hardest) and recommend an effort level; subagents escalate by verification, then effort, then tier | [refinement log, 2026-11-13](methodology/refinement-log.md#2026-11-13--handover-follows-anthropics-model-selection-guidance) |
