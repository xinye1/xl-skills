---
name: handover
description: Produce a self-contained handover prompt that lets the user paste it into a fresh chat and continue a multi-phase plan without drift. Use whenever the user says "handover", "write a handover", "carry on in a new chat", "continue in a fresh chat", "start the next phase in a new chat", "give me a prompt for a new chat", or signals the context is getting full and they want to hop. Also use proactively at the end of a phase in a long plan — even when the user has not said the word "handover" — because chat-level pacing on multi-phase work prevents context rot. The skill verifies phase exit criteria (or captures in-progress state), writes a phase memory entry when a phase actually completed, and emits a prompt that instructs the receiving chat to orchestrate subagents per task and run overall validation itself.
---

# Handover — hop to a fresh chat mid-plan without drift

This skill exists for one moment: a multi-phase plan is partway through, context in the current chat is getting spent (on earlier-phase scaffolding, tool output, review cycles, whatever), and the user wants the next chat to pick up cleanly. The handover prompt is the *only* bridge between chats — if it isn't self-contained, the next chat starts half-blind and the user pays for it for the rest of that session.

**Who this skill is for:** someone executing a long plan one phase at a time (often via `execute-phased-plan`). It also works as a standalone: any time the user wants a fresh chat to continue from a clean starting point, this produces the prompt that makes that possible.

**What this skill is NOT:** it does not execute the next phase. It does not keep going "just to finish this one file". It emits a prompt and stops. The point is to get out of the current chat cleanly so the next chat starts with tight, relevant context.

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

Skip this step for mid-phase handovers — instead, jump to Step 4 and record partial state honestly.

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
name: Phase <N> — <title>
description: Outcome, key decisions, and deviations for Phase <N> of <project name>
type: project
---

## Outcome

- PR #<num>, squash-merged to `<base>` on <YYYY-MM-DD>. Commit: `<sha>`.
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

## Step 4: Write the handover prompt

Use the template below verbatim. **Emit it as a single fenced code block** (triple-backticks or `~~~`) so the user can copy the literal markdown source, markup and all, in one action. Do not render the template directly into the chat as headers, bullets, and checkboxes — that destroys the markup the next chat needs. The reader should see a code block they click-to-copy, not a rendered document. **Do not "tighten up" or summarise the template** — the structure is what makes the next chat productive; collapsing sections loses load-bearing context, and past sessions that trimmed the template always paid for it.

Fill every section. For mid-phase handovers, the "Current status" lists what's done vs. outstanding and the next chat's job is to finish the phase, not start the next. For end-of-phase, the next chat starts Phase N+1.

### Handover prompt template

~~~markdown
# Handover — <project name>, Phase <target-phase> (<"start" | "continue">)

## Current status (as of <YYYY-MM-DD HH:MM>)

**Completed and merged to `<base-branch>`:**
- Phase 0 — <one line>
- Phase 1 — <one line>
- ...
- Phase <N> — <one line>, squash-merged in PR #<num> (commit `<sha>`)

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
- [ ] PR opened, reviewed, squash-merged to `<base>`
- [ ] UAT section for this phase filled in `<path>`
- [ ] <any plan-specific acceptance gate>

## Execution model — subagent orchestration

Do not execute tasks yourself inline. Orchestrate subagents, one per task, and run overall validation yourself at the end:

1. **Decompose this phase into its tasks.** Look in the plan for an explicit task list for this phase. If the plan has one, use it verbatim. If it doesn't (the phase is described in prose, or the task list is vague), **draft a task list yourself from the phase's scope and deliverables, then stop and validate with the user** before dispatching any subagent — say something like: "The plan doesn't list explicit tasks for this phase, so I've drafted the following from the scope. Approve, or tell me what to refine." Once you have a list the user accepts, classify each task as independent (can run in parallel) or sequential (depends on another task's output).
2. **Dispatch one subagent per task.** Launch independent tasks in parallel; launch sequential tasks only after their dependencies report back. Each subagent prompt must be self-contained: plan file path, branch name, guardrails below, and a clear definition of done that **includes the task-level tests the subagent must run and pass before reporting back**. Each subagent should follow `superpowers:executing-plans` internally.
3. **Receive reports and coordinate.** Each subagent reports: what was implemented, which tests passed (`X/Y passing`, lint clean, etc.), any deviations with reasons, and carry-forward notes for dependent tasks. If a subagent's tests are red, it must fix and re-run before the report is accepted — "tests failing" is not a completed task. If a failure blocks a dependent task, stop and resolve before dispatching downstream subagents; do not cascade failures forward.
4. **Run overall validation yourself** (do not delegate). Once all subagents have reported green task-level results, you — the orchestrating agent — run the full integration/validation suite: full tests, lint, type-check, and any E2E/integration tests the plan's exit criteria specify. Task-level tests confirm local correctness; overall validation confirms the pieces integrate. If overall validation is red, diagnose, fix, and re-run before moving on.

Why this split: subagents keep each task's context tight; the orchestrator keeps a coherent view of the phase as a whole and catches integration-level failures that no single task-subagent would see.

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
2. Write a phase memory entry to `<project-memory-dir>/phase_<target-phase>_<short-title>.md` — outcome, key decisions, deviations, carry-forwards. Add a pointer line to `MEMORY.md`.
3. Produce the next handover prompt using the `handover` skill.
~~~

## Step 5: Hand off

Emit the handover prompt and almost nothing else. One short lead-in ("Phase N done. Paste this into a fresh chat:" or "Mid-phase hop — paste this into a fresh chat to continue:") plus the **fenced code block containing the handover**. The code block is non-negotiable: the user needs to copy the literal markdown source — headers, bullets, checkboxes intact — not a rendered view. A rendered handover looks fine in the current chat and pastes as broken plaintext in the next one.

Do not bury the prompt under a chatty summary; the user needs to copy it cleanly. After emitting, stop. Do not offer to start the next phase here. If the user wants to continue in this chat anyway, they'll tell you — but the default after a handover is always: this chat is done.

## Anti-patterns

| Anti-pattern | Why it burns the user |
|---|---|
| Writing the handover before verifying exit criteria | A handover that claims a red phase is green corrupts the next chat's assumptions for its entire duration. Either verify, or mark as mid-phase with honest in-progress state. |
| "See the previous conversation for details" | The next chat has no access to this chat. If it's not in the handover, it doesn't exist. |
| Summarising the plan instead of referencing it | The plan file is authoritative. The handover points at it; it does not replace it. Rewriting the plan in the handover invites drift. |
| Trimming the template to be "more concise" | Every section is load-bearing. Trimming always seems harmless in the moment and always bites the next chat. |
| Leaking long secrets inline | Handover prompts get pasted into shared notes and other chats. Reference the secret store; only inline values the user has explicitly authorised inline. |
| Naming no execution model | Without the subagent-orchestration block, the next chat defaults to executing inline and burns its context on task-level detail instead of integration-level coordination. |
| Continuing "just one more task" after writing the handover | Defeats the point of hopping. Emit the handover and stop. |
| Emitting the handover without a lead-in the user can see | The prompt is the payload; the lead-in tells the user what to do with it. A handover with no framing often gets missed or misused. |

## Composition with other skills

| Skill | Role |
|---|---|
| `execute-phased-plan` | Governs the rhythm of long multi-phase plans end-to-end; this skill is the "emit the handover" step of that rhythm, extracted so it can also be invoked standalone whenever context fills up. |
| `superpowers:executing-plans` | Referenced inside the handover prompt — each subagent spawned by the next chat follows this skill to execute its individual task. |
| `superpowers:subagent-driven-development` | Background pattern for the Step 4 orchestration model embedded in the prompt. |
| `superpowers:verification-before-completion` | Enforced at Step 2 — no end-of-phase handover without fresh verification evidence. |
| `ship` | Usually the last activity of the phase being handed off — push, review, merge, clean up — before the handover fires. |

## When NOT to use this skill

- Single-phase tasks or short changes — no handover needed; just do the work.
- The user has said "execute the whole plan, don't pause" — honour that; phase-level auto-accept overrides this skill's default pacing.
- Experimental / throwaway sessions where context hygiene doesn't matter.

**Note:** an explicit "handover" request from the user should always be respected, regardless of how this chat was started (including handover-launched chats). The user has reasons you can't see — context bloat, a revised plan, a fresh idea that deserves its own chat. Don't second-guess an explicit hop.

## Quick invocation phrases

These trigger this skill — recognise and invoke without asking for clarification (but still do Step 1 to lock down the inputs):

- "handover"
- "write a handover"
- "write a handover prompt"
- "carry on in a new chat"
- "continue in a fresh chat"
- "start the next phase in a new chat"
- "give me a prompt for a new chat"
- "write me a prompt for a fresh chat to continue the plan"
- "hop to a fresh chat"
- (implicit) user notes the context is getting full mid-plan and asks what to do next — suggest a handover and, if they agree, run this skill
