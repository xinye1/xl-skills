# Refinement log

Newest first. Each entry records what prompted the change, the evidence, what changed, what was considered and rejected, and what the pass caught along the way.

## 2026-11-13 — handover follows Anthropic's model-selection guidance

**Trigger.** Anthropic published ["Which Claude model should you build with? Fable, Opus, Sonnet, or Haiku"](https://claude.dev/blog/which-claude-model-should-you-build-with/) on 2026-11-09. The handover skill picks the next chat's orchestrator model and sizes its subagents, so it was checked against the post.

**Where the skill had drifted from the guidance.**

| Skill said | Guidance says | Evidence in the post |
|---|---|---|
| Default orchestrator `sonnet` | "start most work on Opus 5.5 at its default effort level, `medium`"; Sonnet 5.5 for well-scoped, spec-driven work | Task table: "Not sure yet: Opus 5.5, `medium`" |
| No effort level at all | Change effort before model; past `high`, move up a model at a lower effort instead | Opus 5.5 SWE-bench Pro: `medium` ≈ 2.5 points below `high` for ~70% of the cost; `xhigh` +1.4 points for 2.5× the cost |
| Fable "~2.5× opus", prices 1:2:4:10 (Haiku 4.5 $1 … Fable 5.1 $10) | Haiku 5.5 $0.10 (≤100K-token prompts, $0.50 above), Sonnet 5.5 $2, Opus 5.5 $4, Fable 5.2 $8 | Price table; confirmed on the pricing page on 2026-11-13 |
| `haiku` for "rote edits, boilerplate" | Small models for work "where a mistake is cheap to spot, like finding files, running tests and reading logs. Keep code edits and judgment calls on the main model." | Subagent section |
| Escalate by tier | Escalate by self-verification, then effort, then tier; or run at `low` and re-run failures at `high` | Opus 5.5 at `low` with failures re-run at `high`: ~97% for ~$0.17 a task, vs 95.3% for $0.29 at `high` throughout |
| (not covered) | The built-in Explore subagent runs on the session's model, not on Haiku | Subagent section |

**What changed.**

- `handover/SKILL.md` Step 4: the orchestrator is sized to the phase's shape. `sonnet` is for a phase whose tasks and executable exit criteria are already written down, which is also the shape Template A fits. `opus` is the default when unsure. `fable` is for major refactors, migrations, architecture planning, phases leading many subagents, long unattended runs, or when `opus` at `high` already fell short. A new effort rule: `medium` by default, `high` only on evidence, and never `xhigh` or `max` (recommend the next tier instead).
- The handover carries the effort in its frontmatter (`effort:`), header callout and receipt. The receipt always prints `/effort <level>`, and the closing line uses `claude --model … --effort …`. The from-disk check now fails on an unfilled `<recommended effort>`.
- Both execution models (`references/execution-model.md`, `references/execution-model-goal-directed.md`): current prices, `haiku` limited to read-and-report work, an escalation order (verification → effort → tier), the low-first re-run pattern, and explicit `model: haiku` for cheap exploration. The goal-directed version also notes that a lean orchestrator context matters more the bigger the model, because long runs bill mostly as cache reads.
- `pickup/SKILL.md`: lists the effort next to the model, adds `/effort` to the switch message and an effort reminder to the receipt, and treats a missing field (older handovers) as `medium`. Effort is not gated, because a chat can't reliably read its own effort level.

**Considered and rejected.**

- *Defaulting every orchestrator to `opus`.* The post's "start on Opus" is for unknown work. A phase from a written plan with explicit tasks is the spec-driven case it sends to Sonnet 5.5. So the rule keys on the phase's shape, and `opus` is the default only when that shape is unclear.
- *Sending Sonnet 5.5 the goal-directed Template B.* Nothing in the post says Sonnet 5.5 plans better without a procedure. Its advice to write "precisely enough for the most literal model" points the other way, so Template A stays.
- *Gating `/pickup` on effort as it gates on model.* The chat can't read its own effort reliably, so a gate would guess. The receipt shows it instead. Review then suggested that `/pickup` end its turn after the reminder until the user confirms effort. Rejected: that adds a turn to every hop, including the normal path where the handover receipt already had the user run `/effort` before `/pickup`, or start with `claude --effort`. The pickup reminder is the third safety net, not the first.

**What review caught (CodeRabbit CLI on PR #47).**

- The first draft printed `/effort` only for non-`medium` handovers, on the theory that `medium` is Claude Code's default. But `/effort` is saved per model (`modelSettings.<model>.effortLevel` in `~/.claude/settings.json`) and carries into later sessions. This machine has Opus 5.5 saved at `high`, so a `medium` handover would have silently run at `high`. The step is now always printed.
- The same-tier receipt branch still said to print only `/clear` and `/pickup`, contradicting the always-print rule. Eval 0 also expected the receipt to compare against the chat's current effort, which the skill says can't be read. Both fixed.
- The execution models said to leave subagent effort "at the model's default", but an Agent call without `effort` inherits the session's effort. Subagents now start at an explicit `medium`.
- Eval 0 still expected Template A's sections even when the new rules pick `opus`, which takes Template B. It now expects the sections of whichever template the recommended model takes.

**What the pass caught along the way.**

- `summarise-session/references/prices.json` had no `claude-fable-5-2` entry, so Fable 5.2 turns were reported as unpriced. Fixed in PR #46 with the pricing-page rates ($8 / $10 / $16 / $0.20 / $40; fast mode $16 / $80).
- PR #43's idle cache re-write pricing chose Haiku 5.5's prompt-length tier from the trimmed write, not the whole request. A 115K-token request was priced at $0.0075 instead of $0.0375. Fixed in that PR.
- Stale model prices outside handover: `adversarial-review/SKILL.md` called Fable "roughly 2.5×" Opus (it is 2× at Fable 5.2). Fixed in PR #48, which cites `prices.json` as the source.
