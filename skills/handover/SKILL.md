---
name: handover
description: Use when a multi-phase effort needs to continue in a fresh chat — the user says "handover", "write a handover", "carry on in a new chat", "continue in a fresh chat", "start the next phase in a new chat", "give me a prompt for a new chat", "hop to a fresh chat", or signals context is filling up. Saves the handover as a file that `/pickup` loads in the fresh chat after `/clear`. Also use proactively at a phase boundary in a long plan, even unprompted. Run summarise-session first when closing a phase. Not for coordinating a parallel live session — that's cross-session-brief.
---

# Handover — hop to a fresh chat mid-plan without drift

This skill exists for one moment: a multi-phase plan is partway through, context in the current chat is getting spent (on earlier-phase scaffolding, tool output, review cycles, whatever), and the user wants the next chat to pick up cleanly. The handover prompt is the *only* bridge between chats — if it isn't self-contained, the next chat starts half-blind and the user pays for it for the rest of that session.

**Who this skill is for:** someone executing a long plan one phase at a time (often via `execute-phased-plan`). It also works as a standalone: any time the user wants a fresh chat to continue from a clean starting point, this produces the prompt that makes that possible.

**What this skill is NOT:** it does not execute the next phase. It does not keep going "just to finish this one file". It saves the prompt to a handover file, proves the save, and stops. The point is to get out of the current chat cleanly so the next chat starts with tight, relevant context.

**The hop, end to end (CLI):** `handover` saves the prompt to `~/.claude/handovers/<repo>/` → the user runs `/model <recommended>` only if the receipt shows a model mismatch, then `/clear` in the same terminal → `/pickup` in the fresh chat loads the file as its brief. Nothing is copied by hand. `/clear` keeps the old chat on disk (resumable with `/resume`), and the handover file doesn't depend on it: it survives a reboot and waits until someone picks it up, in any later session in that repo. This works like `/compact`, except the user can see and choose exactly what carries over.

## The two handover shapes

A handover is either **end-of-phase** (the current phase actually finished — tests green, PR merged, exit criteria ticked) or **mid-phase** (context is filling up but the phase isn't done). The prompt is structured the same way; the differences are:

| | End-of-phase | Mid-phase |
|---|---|---|
| What's "done" | Phase N, merged | Tasks A, B of Phase N; C, D outstanding |
| Next chat's job | Start Phase N+1 | Finish Phase N |
| Verification evidence | Tests/lint/types/UAT for Phase N | Partial — whatever has been run |
| Phase memory written | Yes (Step 3) | No — phase isn't done |

Figure out which shape applies before writing anything. If you're unsure, ask the user in one short question: "Is Phase N actually finished, or are we hopping mid-phase?"

## Step 1: Confirm the handover's inputs

Before drafting, lock down these four things — ask the user in one message if anything is unclear, don't guess:

1. **Plan file path** (absolute). The handover points at it verbatim; the next chat reads it directly.
2. **Current phase number + title** and whether it's complete or in-progress.
3. **What's been done since the last handover** — tasks completed, PRs merged, tests run. If the user lost track, check `git log` on the current branch and `gh pr list --state merged --limit 5` rather than making them recite it.
4. **Branch + base branch** the next chat should work on (usually the plan says, but confirm).

If the user triggered this skill casually ("handover please"), these don't all need explicit answers — pull what you can from the transcript and git state, and only ask about gaps.

## Step 2: Verify exit criteria (end-of-phase handovers only)

Skip both this step and Step 3 for mid-phase handovers — jump straight to Step 4 and record partial state honestly. (Step 3 writes a phase-complete memory entry; there's no complete phase yet, so there's nothing to memorialise.)

For end-of-phase, before the handover goes out, the phase has to actually be done. Apply `superpowers:verification-before-completion`:

- **Tests:** run the full suite; report `X/Y passing`, not "tests pass".
- **PR:** `gh pr view <n> --json state,mergeCommit` — "merged" ≠ "approved and open". A handover that claims the phase is merged when the PR is still open corrupts the next chat.
- **Lint / types:** `ruff`, `mypy`, `eslint`, `tsc` — whatever the repo uses.
- **UAT / acceptance:** if the plan specifies one, each item ticked.

If any exit criterion fails, **stop and fix it in this chat first**. Do not write an end-of-phase handover for a red phase. If the user insists on hopping anyway ("context is toast, just hand over what we have"), convert to a mid-phase handover and record the failing state honestly in the "Verification evidence" section — future chats deserve accurate inputs more than they deserve an optimistic label.

## Step 3: Write a phase memory entry (end-of-phase only)

Only do this when the phase actually completed. The memory captures the non-obvious parts of what happened — the things `git log` and the plan file won't tell a future reader.

**Location:** `<project-memory-dir>/phase_<N>_<short-title>.md`. If the project has a memory directory set up (e.g. `~/.claude/projects/<project-slug>/memory/`), write there. If not, ask the user where; don't invent a path. Also add a one-line pointer to that project's `MEMORY.md`.

**Type:** `project`.

**Template (keep it to 10–20 lines — skip sections that have nothing worth saying):**

```markdown
---
name: phase-<N>-<short-slug>
description: Outcome, key decisions, and deviations for Phase <N> of <project name>
metadata:
  type: project
---

## Outcome

- PR #<num>, merged to `<base>` on <YYYY-MM-DD> (regular merge commit — never squash). Commit: `<sha>`.
- Tests: `<X/Y passing>`, lint clean, types clean.

## Key technical decisions

- <decision that wasn't forced by the plan — e.g. "switched from X to Y because Z">
- <constraint discovered during implementation that will affect later phases>

## Deviations from plan

- <plan said X> → <did Y> — **Why:** <reason>
- (or "None")

## Carry-forwards to Phase <N+1>

- <anything the next phase needs that isn't in the handover or the plan>
```

Why memory now, not later: the details fade fast. The next chat inherits the handover, but the chat *after that* might be a week later — the memory is what lets future conversations reconstruct what actually happened.

## Step 4: Choose the orchestrator model, then write the matching handover prompt

**First choose the recommended orchestrator model** (`sonnet`, `opus`, or `fable`). The orchestrator decomposes tasks, coordinates subagents, and runs integration validation, so it needs real reasoning capacity:

- **Default to `sonnet`** — a well-planned phase with a clear task list needs coordination, not frontier reasoning.
- **Recommend `opus`** when the phase carries significant integration complexity, cross-cutting refactors, or architectural decisions where the orchestrator's own judgment is load-bearing.
- **Recommend `fable`** (the frontier tier above `opus`, at roughly 2.5× its price) for the phase where the orchestration itself is the hardest part: long-horizon, high-autonomy phases coordinating many parallel or long-running subagents; deep ambiguity the orchestrator must resolve rather than escalate; or plan-shaping decisions whose blast radius spans the remaining phases. If `opus` would orchestrate this phase equally well, `opus` is the right call — but on a *genuine* opus/fable boundary, note that Fable at low effort often matches or beats prior tiers pushed to high effort, so end-to-end (tokens + redone work + your time) it can be the cheaper choice.
- **Never recommend `haiku`** for the orchestrator.

(This is separate from per-task subagent models — those are sized per task in the execution model.)

**The model determines the prompt style.** Matching prompt shape to model tier is what gets the optimal outcome at the lowest token-and-time cost:

- **`sonnet` → Template A (prescriptive).** Explicit steps, checklists, a verbatim procedure — the scaffold is what keeps a mid-tier orchestrator's delegation and validation gates on rails.
- **`opus` / `fable` → Template B (goal-directed).** Both plan better than a prescriptive procedure, and the procedure gets in the way: they follow instructions closely and literally, so a flawed step gets followed faithfully. Give them the goal *with the why* (they use intent to make micro-decisions you can't enumerate), the context, and hard constraints; let them own the orchestration plan and steer at outcome level. Never send them Template A. (`opus` here means Opus 5 or later — it shares Fable 5.1's always-on reasoning, and Anthropic's guidance for current models is that step-by-step scripts for judgement work lower output quality. An older Opus is mid-tier: give it Template A.)

**Write the chosen template into the handover file (Step 5), not into the chat.** The file holds the literal markdown source, markup and all, and `/pickup` loads it verbatim. Asking the user to drag-select dozens of lines out of a terminal is the friction this design exists to remove. **Do not "tighten up" or summarise the chosen template** — every section is load-bearing; Template B is already the lean variant, its brevity is designed, not a licence to trim further.

Fill every section. For mid-phase handovers, the status lists what's done vs. outstanding and the next chat's job is to finish the phase, not start the next. For end-of-phase, the next chat starts Phase N+1.

**Inline the execution model.** Each template has a REQUIRED slot: fill it verbatim with `references/execution-model.md` (Template A) or `references/execution-model-goal-directed.md` (Template B) — both in this skill's folder. Do not paraphrase, trim, or cross-wire them (the goal-directed file is constraints-and-intent, the other is a procedure — that difference is the whole point). The emitted prompt must be self-contained: the receiving chat may not load this skill, so the model travels inside the prompt.

**Placeholders:** replace *every* `<recommended orchestrator model>` placeholder in the header block — the H1 title suffix, the ⚠️ callout, and every occurrence in the model check (Template A's "Before you start" section, Template B's "first action" paragraph). A raw placeholder in the self-check tells the receiving agent to compare itself against the literal string, which breaks the check. In both templates, **leave `<your current model>` verbatim** — that's the one placeholder the receiving agent fills at runtime from its own environment, not you.

### Template A — prescriptive (orchestrator: `sonnet`)

~~~markdown
# Handover — <project name>, Phase <target-phase> (<"start" | "continue">) — orchestrate on `<recommended orchestrator model>`

> **⚠️ Set your model to `<recommended orchestrator model>` before continuing.** If this chat is on a weaker model, switch with `/model` now.

## Before you start — orchestrator model check

This phase is meant to be orchestrated on **`<recommended orchestrator model>`** (the orchestrator decomposes tasks, coordinates subagents, and runs integration validation — not a job for `haiku`).

**As your very first action, before reading further or doing any work:** check the model you are running as (shown in your environment / system context). Capability order is `haiku` < `sonnet` < `opus` < `fable`. If you are running on something *weaker* than `<recommended orchestrator model>`, **stop and ask the user**, then wait for their reply before continuing:

> This handover recommends orchestrating on `<recommended orchestrator model>`, but this chat is running on `<your current model>`. Switch with `/model` (recommended), or reply "continue" to proceed on `<your current model>` anyway.

Do not begin decomposition or dispatch until the user has switched or explicitly confirmed. (This is only about the orchestrating chat — task subagents are sized per task in the execution model below.)

## Current status (as of <YYYY-MM-DD HH:MM>)

**Completed and merged to `<base-branch>`:**
- Phase 0 — <one line>
- Phase 1 — <one line>
- ...
- Phase <N> — <one line>, merged in PR #<num> (commit `<sha>`)

**In-progress (mid-phase handovers only — omit section otherwise):**
- Phase <N>, tasks done: <task A>, <task B>
- Phase <N>, tasks outstanding: <task C>, <task D>
- Branch: `<branch>` (not yet merged)

**Verification evidence:**
- `<test command>` — `X/Y passing` (or "not yet run for task C")
- `<lint command>` — clean
- `<type-check command>` — clean
- UAT: <link + sections ticked, or "N/A">

## Plan reference

Full plan: `<absolute path to plan file>`
Phase-specific plan (if one exists): `<path>`

## Your job: Phase <target-phase> — <phase title>

<one-paragraph scope summary pulled from the plan>

**Deliverables** (copied from the plan — for mid-phase, list only outstanding tasks):
- <file / module> — <one-line responsibility>
- <file / module> — <responsibility>
- ...

**Exit criteria** (how you know this phase is done):
- [ ] <test command> — all green
- [ ] PR opened, reviewed, merged to `<base>` (regular merge commit — never squash)
- [ ] UAT section for this phase filled in `<path>`
- [ ] <any plan-specific acceptance gate>

## Execution model — subagent orchestration

<!-- REQUIRED SLOT: replace this comment with the FULL contents of references/execution-model.md, verbatim. Never emit the handover with this slot unfilled, paraphrased, or trimmed — the receiving chat gets only what is pasted here. -->

## Branch + conventions

- Branch off `<base>`: `git checkout <base> && git pull && git checkout -b <type>/<short-name>` (or continue on `<existing-branch>` for mid-phase).
- Conventional commits only (`feat(<scope>): ...`, `fix(<scope>): ...`).
- After the last subagent has reported back **AND** you (the orchestrator) have run the overall validation suite green (step 4 of the execution model): use the `ship` skill to push, review, merge, clean up. Do not ship on the strength of task-level test reports alone — the overall validation gate must pass first, otherwise integration bugs ship with the PR.

## Key guardrails (from `CLAUDE.md` — enforce in reviews)

- <guardrail 1, verbatim from CLAUDE.md>
- <guardrail 2>
- ...

## Environment / secrets

- `<ENV_VAR>` — <how to obtain, e.g. "from Supabase Vault; never commit">
- `<ENV_VAR>` — <"see <secret store>", or an inline value only if the user authorised it>

## Deviations from plan (if any)

- <deviation that affects this phase, with reason>
- <or "none">

## Checkpoint at end of this phase

Before handing over to the next phase, in this order:

1. Verify exit criteria (tests green, PR merged, UAT ticked).
2. Run `summarise-session` for the reflective pass — surface gotchas, deviations, subagent/orchestration findings, and any follow-ups (issues to file, memories to save) for the user to action. This is what decides what the phase memory should persist.
3. Write a phase memory entry to `<project-memory-dir>/phase_<target-phase>_<short-title>.md` — outcome, key decisions, deviations, carry-forwards. Add a pointer line to `MEMORY.md`.
4. Produce the next handover prompt using the `handover` skill.
~~~

### Template B — goal-directed (orchestrator: `opus` / `fable`)

Goals, reasoning, and constraints — no numbered procedure. The "why" in the Goal section is load-bearing, not decoration: write the real intent (who benefits, what it unblocks), because the receiving agent uses it to resolve decisions the plan doesn't cover.

~~~markdown
# Handover — <project name>, Phase <target-phase> (<"start" | "continue">) — orchestrate on `<recommended orchestrator model>`

> **⚠️ Set your model to `<recommended orchestrator model>` before continuing.** If this chat is on a weaker model, switch with `/model` now.

**As your very first action:** check the model you are running as. Capability order is `haiku` < `sonnet` < `opus` < `fable`. If you are on something weaker than `<recommended orchestrator model>`, stop and ask the user to switch with `/model` before doing any work. If they decline: on `opus` 5 or later (when `fable` was recommended) this prompt's style still fits — proceed once they explicitly say "continue"; on `sonnet` or an older `opus`, do not proceed on this prompt — a goal-only prompt lets a mid-tier orchestrator drift, so ask them to have it regenerated in the prescriptive style (the authoring chat's `handover` skill, Template A); on `haiku` or an unrecognised model there is no valid template — ask them to switch to `sonnet`, `opus`, or `fable`, and never orchestrate on `haiku`.

## Goal

<What Phase <target-phase> must achieve, stated as outcomes — then the why: the larger project this serves, who benefits, and what completing this phase unblocks. 2–4 sentences, drawn from the plan.>

**Done means:**
- [ ] <test command> — all green
- [ ] PR reviewed and merged to `<base>` (regular merge commit — never squash)
- [ ] UAT section for this phase filled in `<path>`
- [ ] <any plan-specific acceptance gate>

## Context (as of <YYYY-MM-DD HH:MM>)

- **Plan (authoritative — read it; this handover points at it, it does not replace it):** `<absolute path>`; phase-specific plan (if any): `<path>`
- **Completed and merged to `<base-branch>`:** Phase 0 — <one line>; … Phase <N> — <one line>, PR #<num> (`<sha>`)
- **In-progress (mid-phase only, else omit):** done — <tasks>; outstanding — <tasks>; branch `<branch>` (unmerged)
- **Verification evidence:** `<test command>` — `X/Y passing`; `<lint>` — clean; `<types>` — clean; UAT: <link or "N/A">
- **Deviations from plan so far:** <deviation + reason, or "none">
- **Environment / secrets:** `<ENV_VAR>` — <how to obtain; reference the store, never inline>

## Constraints

- Branch: off `<base>` as `<type>/<short-name>` (or continue `<existing-branch>` mid-phase). Conventional commits only.
- Guardrails (from `CLAUDE.md` — enforce in reviews):
  - <guardrail 1, verbatim>
  - <guardrail 2>

## How you work

<!-- REQUIRED SLOT: replace this comment with the FULL contents of references/execution-model-goal-directed.md, verbatim. Never emit the handover with this slot unfilled, paraphrased, or swapped for the prescriptive execution model. -->

## At phase end

Once every box in **Done means** is ticked: run `summarise-session` (the reflective pass that decides what to persist), write a phase memory entry to `<project-memory-dir>/phase_<target-phase>_<short-title>.md` with a pointer line in `MEMORY.md`, then produce the next handover with the `handover` skill.
~~~

## Step 5: Save, verify, hand off

The handover file is the only bridge between chats, so it has to be saved where it survives a reboot, and the save has to be proven before the user runs `/clear`.

**Where it goes.** `~/.claude/handovers/<repo>/<YYYY-MM-DD-HHMM>-<slug>.md`, for example `2026-09-23-1432-phase-3-start.md`.
- `<repo>` is the main checkout's folder name, so every worktree and branch of a repo shares one queue: `c=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && basename "$(dirname "$c")" || basename "$PWD"`.
- It is keyed by name, not path, so the queue still matches if the repo is cloned somewhere else, or `~/.claude/handovers/` is copied to a new machine.
- Never `/tmp`: on some machines it's a tmpfs that a reboot wipes.
- Never overwrite an existing file: if the name is taken, add `-2`.
- The Write tool needs an absolute path, so resolve `$HOME` first.

**Frontmatter first, then the filled template.** `/pickup` lists the queue from these fields:

```yaml
---
title: <project>, Phase <N> (<start|continue>) — <one-line job>
repo: <repo>
cwd: <absolute working directory>
branch: <branch the next chat works on>
model: <recommended orchestrator model>
kind: <end-of-phase | mid-phase>
written: <YYYY-MM-DDTHH:MM, local time>
from_session: ${CLAUDE_SESSION_ID}
status: pending
---
```

**Verify from disk. Never skip this.** Re-read the file with one command, then report what it printed:

```bash
f="<absolute path>"; d=$(dirname "$f")
test -s "$f" && echo "saved: $(wc -l <"$f") lines" || echo "FAIL: missing or empty"
grep -q '^# Handover — ' "$f" && echo "ok: title" || echo "FAIL: no '# Handover —' title"
grep -qE 'Default: every task in this phase is delegated|Constraints and intent, not a procedure' "$f" && echo "ok: execution model inlined" || echo "FAIL: execution model missing"
grep -qE 'REQUIRED SLOT|<recommended orchestrator model>' "$f" && echo "FAIL: unfilled slot or placeholder" || echo "ok: no unfilled placeholders"
tail -n 3 "$f" | grep -q 'handover` skill' && echo "ok: complete to the end" || echo "FAIL: file looks cut off (closing section missing)"
echo "waiting in $(basename "$d"): $(ls "$d"/*.md 2>/dev/null | wc -l)"
```

Any `FAIL`: fix the file and re-run the check. Never show a green receipt over a failed check. If the file genuinely can't be written (permissions, disk), say so plainly and print the handover in a fenced code block as the last resort, so it isn't lost.

**Receipt: the only thing you print.** It is short, and every tick comes from the check above:

```text
✓ Handover saved — <title>
  file      ~/.claude/handovers/<repo>/<name>.md
  checks    ✓ <L> lines re-read from disk  ✓ execution model inlined  ✓ no unfilled placeholders  ✓ complete to the end
  model     this phase wants <recommended> · this chat is on <current>   ✓ nothing to switch | ⚠ switch first
  waiting   <W> handover(s) for <repo>
  this chat ${CLAUDE_SESSION_ID}  (optional: claude --resume <id>; the file stands alone)

Next, in this terminal:
  1. /model <recommended>   ← only when the model line shows ⚠
  2. /clear                 ← this chat stays saved on disk
  3. /pickup
```

**The `model` line decides whether step 1 is printed.** Compare the recommended model with the model you are running as (from your environment / system context, the same source the handover's own first-action check reads), by tier: `haiku` < `sonnet` < `opus` < `fable`.
- **Same tier:** the line ends `✓ nothing to switch`, and the `/model` step is left out (print `/clear` then `/pickup` as steps 1 and 2). The line stays so the user can see why there is no `/model` step.
- **This chat is weaker than recommended:** `⚠ switch first`, and print the `/model` step. Without it the fresh chat stops at its own model check and asks.
- **This chat is stronger than recommended:** `⚠ higher than this phase needs`, and print the `/model` step marked `(optional, cheaper)`. The handover works on the stronger model, but the phase doesn't need it.

If you can't tell which model you are running as, say so on the model line and print the `/model` step.

Then stop. Do not print the handover body, and do not offer to start the next phase here. If the user wants to carry on in this chat anyway, they'll say so, but the default after a handover is always: this chat is done.

## Anti-patterns

| Anti-pattern | Why it burns the user |
|---|---|
| Writing the handover before verifying exit criteria | A handover that claims a red phase is green corrupts the next chat's assumptions for its entire duration. Either verify, or mark as mid-phase with honest in-progress state. |
| Acceptance criteria that list only what the check might *read*, not "the check never ran" | Criteria for a scheduled or future check (a nightly run, a soak, a deploy verification) must name what to do if the run never reaches the check: the run dies upstream, the input is missing, or the value is absent. Measured 2026-09-24: a night-2 handover said "same value = correct, increase = fault, decrease = deleted"; the night died upstream and the check had nothing to test. The next chat had to invent the ruling ("not tested, n=0 — not a pass"). Give that outcome its own line, and say whether it blocks the next step. |
| "See the previous conversation for details" | The next chat has no access to this chat. If it's not in the handover, it doesn't exist. |
| Summarising the plan instead of referencing it | The plan file is authoritative. The handover points at it; it does not replace it. Rewriting the plan in the handover invites drift. |
| Trimming the template to be "more concise" | Every section is load-bearing. Trimming always seems harmless in the moment and always bites the next chat. |
| Leaking long secrets inline | Handover files persist on disk indefinitely and get copied into other chats and notes. Reference the secret store; only inline values the user has explicitly authorised inline. |
| Recommending `fable` or `opus` "to be safe" | The premium tiers pay off only where the orchestration or task is genuinely beyond the tier below (list prices scale ~1:2:4:10 haiku→fable). On routine phases they burn a multiple of the necessary spend for the same outcome. Size the model to the phase — in both directions. |
| Sending `opus` / `fable` the prescriptive template (A) | They follow flawed steps faithfully and plan better without them — the crutches get in the way. They get goal + why + context + constraints (Template B) and own the orchestration plan. |
| Sending `sonnet` the goal-directed template (B) | The prescriptive scaffold is what keeps a mid-tier orchestrator's delegation gate and validation steps on rails; goals-only prompting lets them drift. Prompt style follows the model, both directions. |
| Naming no execution model | Without the subagent-orchestration block, the next chat defaults to executing inline and burns its context on task-level detail instead of integration-level coordination. |
| Executing a task inline without naming the exception | The whole point of hopping was a clean orchestrator context; an inline task reloads task-level detail into it and re-bloats the very context the handover was meant to keep tight. Default to a subagent; if you go inline, state why in one line (Template A's execution model names the allowed exceptions). |
| Continuing "just one more task" after writing the handover | Defeats the point of hopping. Emit the handover and stop. |
| Printing the handover body in the chat | In a terminal, that means drag-selecting dozens of lines, and a copy that goes astray loses the notes. The file is the handover and `/pickup` loads it; the chat gets the receipt only. |
| A receipt without the from-disk check | "Saved ✓" from memory of the Write call is a claim, not evidence. The user is about to `/clear` on the strength of that tick, so it must come from re-reading the file. |
| Saving to `/tmp` or the repo's working tree | `/tmp` can be wiped by a reboot, and a working-tree file gets swept up by `git add` or deleted by a cleanup. The handover queue lives in `~/.claude/handovers/`. |
| A receipt with no next steps | The user runs `/clear` → `/pickup` (and `/model` when needed) straight from the receipt. Leave a step out and the fresh chat starts on the wrong model or never loads the handover. |
| Printing the `/model` step when the chat is already on the recommended model | The user can't tell whether it matters, so they stop trusting the receipt's steps. Compare first: print `/model` only on a mismatch, and keep the `model` line so the missing step is explained. |

## Composition with other skills

| Skill | Role |
|---|---|
| `pickup` | The receiving half. In the fresh chat, `/pickup` lists this repo's waiting handovers, loads the chosen one in full, checks it isn't stale, archives it to `picked-up/` (never deleted), and starts on it as the chat's brief. |
| `summarise-session` | The backward-looking companion. At a phase boundary, run `summarise-session` *first* — its retrospective surfaces the gotchas, deviations, and follow-up candidates (issues to file, memories to save) that this skill's "Deviations from plan", "Key guardrails", and Step 3 phase memory then carry forward. The summary is the sense-making pass; the handover is the persistence + forward pass. |
| `execute-phased-plan` | Governs the rhythm of long multi-phase plans end-to-end; this skill is the "emit the handover" step of that rhythm, extracted so it can also be invoked standalone whenever context fills up. |
| `superpowers:executing-plans` | Referenced inside the handover prompt — each subagent spawned by the next chat follows this skill to execute its individual task. |
| `superpowers:subagent-driven-development` | Background pattern for the orchestration model embedded *inside* the emitted handover prompt — the receiving chat uses that pattern to dispatch per-task subagents. |
| `superpowers:verification-before-completion` | Enforced at Step 2 — no end-of-phase handover without fresh verification evidence. |
| `ship` | Usually the last activity of the phase being handed off — push, review, merge, clean up — before the handover fires. |

## When NOT to use this skill

- Single-phase tasks or short changes — no handover needed; just do the work.
- The user has said "execute the whole plan, don't pause" — honour that; phase-level auto-accept overrides this skill's default pacing.
- Experimental / throwaway sessions where context hygiene doesn't matter.

**Note:** an explicit "handover" request from the user should always be respected, regardless of how this chat was started (including handover-launched chats). The user has reasons you can't see — context bloat, a revised plan, a fresh idea that deserves its own chat. Don't second-guess an explicit hop.
