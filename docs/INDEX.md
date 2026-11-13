# xl-skills docs index

A map of the decisions, reports and method documents for the skills in this repo. Each skill's own behaviour lives in `skills/<name>/SKILL.md`; this folder records how and why the skills changed.

These docs start on 2026-11-13. For earlier changes, see the git log and the merged PRs.

## Methodology

- [Refinement log](methodology/refinement-log.md): dated entries, one per skill refinement. Each records what prompted it, the evidence, what changed, what was considered and rejected, and what the pass caught.

## Decisions

| Date | Skill | Decision | Where |
|---|---|---|---|
| 2026-11-13 | handover, pickup | Size the orchestrator to the phase's shape (`sonnet` for well-scoped, `opus` by default, `fable` for the hardest) and recommend an effort level; subagents escalate by verification, then effort, then tier | [refinement log, 2026-11-13](methodology/refinement-log.md#2026-11-13--handover-follows-anthropics-model-selection-guidance) |
