# Refinement log

Newest first. Each entry records what prompted the change, the evidence, what changed, what was considered and rejected, and what the pass caught along the way.

## 2026-11-17 — poteto's pstack as a plugin; ship gains a verification gate

**Trigger.** The user: "there's a set of new skills we need to add, one around improving baseline linting and one about verification, following poteto's … advice." Their first answers were to copy and adapt pstack's `correct` and `create-verification-skill` ("Copy and adapt (Recommended)", "Both, one skill (Recommended)", "Generator + ship gate (Recommended)").

**Three course changes, in order.**

1. *Which repo.* Work began in the Concord delivery kit (delivery-guardrail), because the question spoke of "the kit". The user then said: "this is also being done to the concord project delivery-guardrail skills (spin-offs from this repo), so for future instances we should align both and make sure this repo updates on the skills on this level (applying all project), and the concord project one adapts changes as appropriate for the project." The kit worktree, which had no changes, was removed, and the work moved here. The rule is in [upstream.md](../upstream.md) and in Claude's project memory.
2. *Copies.* Adapted copies of both skills were drafted here, each with poteto's MIT licence. Additions were a "raise the baseline" path in `correct` (count each candidate rule's violations, turn it on, fix it, or ratchet it) and, in the generator, a Verdict section and a git-ignored evidence folder.
3. *Plugin instead.* The user, before anything was committed: "i think pstack should be directly downoaded as plugins, and my related skills such as `ship` should reference and invoke them. this way I won't need to worry about updating these skills myself, instead just follow any updates from the source." The copies were deleted. pstack was installed (`claude plugin marketplace add cursor/plugins`, `claude plugin install pstack@cursor-plugins --scope user`; version 0.15.43, commit `e1cc031`), and `"autoUpdate": true` was set on the `cursor-plugins` marketplace in `~/.claude/settings.json`.

**Why the plugin is better, and what it costs.**

- Gained: no copies to keep in step, and every upstream fix arrives on its own. That matches the user's aim.
- Lost: the "raise the baseline" detail in `correct` (upstream keeps one sentence: "If the pattern is already common, fail only when a change adds more"), and the generator's Verdict and evidence-folder sections. The parts the gate depends on now live in `ship`'s brief to the verifier, so the gate doesn't depend on the generator's wording.
- Risk: updates arrive unreviewed. The rule is to depend on a pstack skill's name and purpose, never its wording.

**How they are started.** A headless test (2026-11-17, `claude -p`) called the Skill tool on `pstack:create-verification-skill`. It refused: "cannot be used with Skill tool due to disable-model-invocation. Ask the user to run /pstack:create-verification-skill themselves". Every pstack skill but `setup-pstack` is set this way. So `ship` and `summarise-session` either have the user type `/pstack:<name>`, or, on their go-ahead, read the installed `SKILL.md` and follow it, after the plugin's Claude Code adapter. That is the route the adapter itself prescribes. The install path comes from `~/.claude/plugins/installed_plugins.json`, and the lookup command was run.

**What changed in this repo.**

- `ship` Step 3b, a verification gate before the first push. A fresh subagent that didn't write the change proves it in the real app. It uses the repo's `verify-<app>` skill. A set-up check blocks shipping when pstack or that skill is missing, until the user confirms setting it up. It returns `PASS` / `PASS+NOTES` / `FAIL`, which goes in the PR's `## Verification`. Merging (Step 7) needs a verdict that covers the head. State A2 enters through 3b, and the summary table has a Verify column. The independent-verifier rule and the verdict words are cited from pstack's Shipping playbook.
- `summarise-session` offers `/pstack:correct` when a correction repeats, instead of another memory line.
- README "Plugins these skills use"; [upstream.md](../upstream.md); `.gitignore` ignores `.worktrees/`.

**Considered and rejected.**

- *Letting ship go ahead, by hand, when the verification tooling is missing.* That was the first draft. The question was put to the user, and they ruled: "verification should become a standard step like code review, so any setup should have verify available, and if not then shipping should block and ask to confirm to install it." Their wording assumed the missing piece was pstack itself. The draft meant the repo's own `verify-<app>` skill. The ruling's principle is applied to both: shipping checks that pstack is installed on every run, and that the repo has a verify skill whenever the gate applies. Either one missing blocks and asks to set it up (install pstack, or generate the skill and commit it in this PR). The one way past is the user explicitly saying to ship without verification, recorded in the PR body as `skipped at the user's instruction`. That last escape is an inference from "ask to confirm", and the user was told so.
- *Keeping a thin own `correct` for the baseline detail.* That brings back the maintenance the user wants to drop. If upstream's one sentence proves too thin in use, the detail can come back as a separate skill that names `correct` and doesn't copy it.

**What the pass caught.**

- The ruff advice drafted for the copy was tested with ruff. `banned-api` with `msg` prints the fix in the error. The copy is gone, but the result shows upstream's "a lint whose error names the fix" works in ruff without custom code.
- Evidence inside a worktree: in a scratch repo, a git-ignored folder doesn't block `git worktree remove` and an untracked one would. The first draft put evidence in a git-ignored folder for that reason, but removing the worktree deletes the folder too, so the PR's evidence links would die. CodeRabbit caught it (below).

**What review caught (CodeRabbit CLI on PR #49: 4 findings, all fixed).**

- Evidence in a git-ignored folder inside the worktree is deleted with the worktree in Step 8. It now goes in a durable folder outside the repo (`~/verify-evidence/<repo>/<branch>/<run>/`), copied out if the repo's verify skill writes it inside.
- A changed path the verifier couldn't reach was only "reported", while Step 7 accepted `PASS+NOTES`, so an unverified path could merge. A new verdict, `INCOMPLETE`, doesn't pass Step 7. Only the user's explicit go-ahead to skip the path does, and the PR records it.
- New behavior that no feature file covers could pass undriven. The verifier now adds the missing feature file in the same PR and drives it, and never passes changed behavior it didn't drive.
- In a push-coupled repo, review (Step 4) runs before the first push, after the verdict. A behavior-changing review fix now needs re-verifying before the next push, not only before merge.

**Survey of the rest of pstack** (the user asked which other poteto skills fit their workflow). A read-only subagent read all 58 skills at `e1cc031`. Two of its claims were spot-checked: only `setup-pstack` lacks `disable-model-invocation: true`, and `unslop` rule 13 bans dashes. With pstack installed, all of them are now available by typing `/pstack:<name>`. The shortlist for wiring into these skills:

- `show-me-your-work`: a decision log for long or unattended runs, which `handover` could point at.
- `principle-explain-the-number` with `benchmark-checklist`: vetting a measured number.
- `reflect`: into `summarise-session`.
- `blast-radius`.
- `interrogate`'s "a finding survives only if a run proves it": into `adversarial-review`.
- `sharpen`.

**Still to do.** delivery-guardrail adapts this: whether the team installs pstack too, Azure DevOps commands, `guardrail:` names. A session working in that repository does it.

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
