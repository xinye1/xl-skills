---
name: execute-phased-plan
description: Execute a long, multi-phase implementation plan one phase at a time, stopping at every phase boundary and producing a self-contained handover prompt so the user can resume in a fresh chat. Use whenever the user says "execute this plan phase by phase", "do one phase at a time", "stop after phase X", "write a handover prompt", "give me a prompt for a new/fresh chat to continue", or otherwise signals they want chat-level pacing to avoid burning context on a plan with many phases. Also use when the user hands over a plan with 3+ numbered phases and doesn't explicitly ask for end-to-end auto-accept — long plans default to this pacing unless the user overrides. Trigger even when the phrasing is casual ("don't carry on with the next phase", "pause after this one") — the common thread is: finish one phase, stop, hand off.
---

# Execute Phased Plan — One Phase per Chat, Handover Between

This skill governs the **rhythm** of executing a long implementation plan, not the implementation itself. Each phase is done by whatever sub-skill fits (`superpowers:subagent-driven-development`, `superpowers:executing-plans`, manual editing, etc.); this skill's job is to stop cleanly at the phase boundary and produce a handover prompt that lets the user start the next phase in a fresh chat with full context and zero drift.

**Why chat-level pacing matters:** A 6-phase plan executed in one chat burns the entire context window on early-phase scaffolding noise, degrades quality by the time the interesting business logic phases run, and makes retries expensive. Cutting at phase boundaries keeps each chat's context tight around one phase's deliverables. The handover prompt is the *only* bridge between chats, so it has to be genuinely self-contained.

**The first handover comes first.** The chat where the plan was brainstormed, written, or reviewed is already noisy with that upstream context. Executing Phase 1 in that same chat imports all of it into Phase 1 — exactly what phase pacing is trying to prevent. So this skill's default first action is to emit a handover prompt for Phase 1 and stop, letting the user start Phase 1 in a fresh chat. Execution starts in chat 2, not chat 1.

## Step 0: Confirm scope

Before doing anything, confirm with the user — in one short message — these three things:

1. **Plan file path** (absolute, so the handover prompt can reference it verbatim).
2. **Which phase to execute now.** If unclear from the transcript, ask: "Phases 0–2 look merged from git log — start Phase 3 next?"
3. **Execution mode for this phase.** Options:
   - **Subagent-driven** (recommended for 5+ independent tasks) → invokes `superpowers:subagent-driven-development`
   - **Inline** (for shorter phases or phases with tight sequential deps) → invokes `superpowers:executing-plans` or manual step-through
   - **Manual** (user will drive, Claude assists) → no sub-skill invocation

Once confirmed, **state the phase boundary explicitly**: "Executing Phase 3 only. Will stop at Phase 3 exit criteria and produce a handover prompt — no Phase 4 work."

This single sentence prevents the most common failure mode: Claude finishing one phase and cheerfully starting the next.

## Step 1: Emit the first handover prompt (skip only if executing a handover-launched chat)

Default behaviour: once scope is confirmed, **immediately produce a handover prompt for the current phase** using the template in Step 5, then stop. Do not start implementing. The user pastes that prompt into a fresh chat, and Phase 1 executes there.

Why this matters: if the user invoked you after brainstorming, plan-writing, spec review, or any other upstream work, that chat's context is already partially spent. Importing it into execution defeats the whole point of phase pacing. A fresh chat that *starts* from the handover prompt has exactly the context Phase 1 needs — no more, no less.

**Skip this step and go straight to Step 2 only if** one of these is true:

- The user explicitly overrides: "execute here", "do it in this chat", "no handover, just run it", "I'm already in a fresh chat".
- The current chat is itself a handover-launched chat — detectable when the user's opening message closely matches the `# Handover —` template (in which case this IS the clean execution chat, just run the phase).
- The plan has a single phase and the user didn't ask for pacing — this skill shouldn't have triggered in the first place; proceed normally.

In all other cases, emit the handover and stop. If you're unsure, emit the handover and ask: "I've drafted the Phase N handover. Want to start Phase N in a fresh chat (recommended), or execute here?"

## Step 2: Execute the single phase via subagent orchestration

**Default execution model for every phase:** decompose the phase into its constituent tasks (as listed in the plan), then orchestrate subagents — one per task. Do not execute tasks yourself inline unless the user explicitly chooses Manual mode in Step 0.

### 2a: Decompose and dispatch

Read the plan's task list for this phase. For each task:

1. **Classify dependencies** — which tasks are independent (can run in parallel) vs. sequential (must wait for a prior result).
2. **Dispatch subagents** — launch independent tasks in parallel; launch sequential tasks only after their dependencies report back. Each subagent prompt must be self-contained: include the plan file path, branch name, relevant guardrails from CLAUDE.md, and a clear definition of done for that task **including the task-level tests the subagent must run and pass before reporting back**.

Each subagent should follow `superpowers:executing-plans` internally. Apply the usual dev-loop conventions from CLAUDE.md (conventional commits, branch off base, PR → base, CodeRabbit, CI green, squash-merge).

### 2b: Receive reports and coordinate

As subagents complete, collect their reports. Each report must include:

- What was implemented
- Which tests were run and their result (`X/Y passing`, or `lint clean`, etc.)
- Any deviations from the plan, with reasons
- Any carry-forward notes for dependent tasks

If a subagent reports a failure or deviation that blocks a dependent task, **stop and resolve it before dispatching downstream subagents**. Do not cascade failures forward.

If a subagent's task-level tests are red, the subagent must fix and re-run before the report is accepted as complete. A report that says "tests failing" is not a completed task.

### 2c: Overall validation testing

Once all subagents have reported back with green task-level results, **run the full integration/validation test suite yourself** (do not delegate this):

- Full test suite (`X/Y passing`)
- Lint + type-check (whatever the repo uses: `ruff`, `mypy`, `eslint`, `tsc`)
- Any integration or E2E tests specified in the plan's exit criteria

This is the phase-level gate — individual task tests confirm local correctness; overall validation confirms the tasks integrate correctly. If overall validation is red, diagnose, fix, and re-run before moving to Step 3.

While executing, keep three things close to hand:

- **Exit criteria** for this phase from the plan (tests passing, PR merged, UAT green, whatever the plan states).
- **Deviations from plan** — aggregate deviations reported by subagents, plus any discovered during overall validation. These go into the handover.
- **Secrets / credentials** provided inline by the user — mark their origin so the handover can reference them without re-leaking them into git-tracked files.

## Step 3: Verify exit criteria before stopping

Before producing the handover, confirm the current phase actually ended. Apply `superpowers:verification-before-completion`:

- Tests: run the full suite; report pass count (`X/Y passing`), not "tests pass".
- PR: check merge status (`gh pr view <n> --json state,mergeCommit`). "Merged to `dev`" ≠ "open and approved".
- UAT / acceptance checklist: if the plan specifies one, confirm each item is ticked.
- Lint / types: `ruff`, `mypy`, `eslint`, `tsc` — whatever the repo uses.

If any exit criterion fails, **stay in this chat** and fix it. Do not write the handover for the *next* phase while the current one is red. A handover that says "Phase N complete" when it isn't is a lie that corrupts the next chat.

## Step 4: Write a phase memory entry

After exit criteria are green, write a memory file for this phase before producing the handover. This gives future chats — and future conversations months from now — a record of what actually happened, not just what the plan said would happen.

**Memory location:** `<project-memory-dir>/phase_<N>_<short-title>.md` where `<project-memory-dir>` is the active project's memory directory (e.g. `~/.claude/projects/<project-slug>/memory/`). Also add a pointer line to `MEMORY.md`.

**Memory type:** `project` — ongoing decisions and technical facts not otherwise derivable from code.

**What to capture** (only the non-obvious parts — don't narrate the plan itself, the code already captures what was built):

```markdown
---
name: Phase <N> — <title>
description: Outcome, key decisions, and deviations for Phase <N> of <project name>
type: project
---

## Outcome

- PR #<num>, squash-merged to `<base>` on <date>. Commit: `<sha>`.
- Tests: `<X/Y passing>`, lint clean, types clean.

## Key technical decisions

- <decision that wasn't forced by the plan — e.g. "switched from X to Y because Z">
- <constraint discovered during implementation that will affect later phases>
- <non-obvious invariant or integration detail>

## Deviations from plan

- <what the plan said> → <what was actually done> — **Why:** <reason>
- (or "None")

## Carry-forwards to Phase <N+1>

- <anything the next phase needs to know that isn't in the handover or the plan>
```

Keep it tight — 10–20 lines is ideal. Skip sections that have nothing worth saying (e.g. "Deviations: None" is fine; "Key decisions: we used asyncpg as planned" is noise).

For the first handover (Step 1), there is nothing to record yet — write the memory after the *executing* chat completes the phase. The handover template instructs the executing chat to write this memory at the end.

## Step 5: Produce the next-phase handover prompt

Whether emitting the first handover (Step 1) or the between-phases one after execution, the structure is identical. The only difference is that the first handover has no "Verification evidence" or "Deviations" yet — leave those sections either blank or mark "N/A — Phase 1 has not started".

### Handover prompt template

Use the template below. Write the prompt as a fenced code block so the user can copy the whole thing into the next chat in one go. Do not rephrase, summarise, or shorten the template — past sessions where the handover was "tightened up" lost load-bearing context.

~~~markdown
# Handover — <project name>, Phase <N+1>

## Current status (as of <YYYY-MM-DD HH:MM>)

**Completed and merged to `<base-branch>`:**
- Phase 0 — <one line>
- Phase 1 — <one line>
- ...
- Phase <N> — <one line>, squash-merged in PR #<num> (commit `<sha>`)

**Verification evidence for Phase <N>:**
- `<test command>` — `X/Y passing`
- `<lint command>` — clean
- `<type-check command>` — clean
- UAT: <link to UAT doc + which sections are ticked, or "N/A">

## Plan reference

Full plan: `<absolute path to plan file>`
Phase-specific plan (if one exists): `<path under docs/superpowers/plans/>`

## Your job: Phase <N+1> — <phase title>

<one-paragraph scope summary pulled from the plan>

**Deliverables** (copied from the plan):
- <file / module to create or modify> — <one-line responsibility>
- <file / module> — <responsibility>
- ...

**Exit criteria** (how you know Phase <N+1> is done):
- [ ] <test command> — all green
- [ ] PR opened, reviewed, squash-merged to `<base>`
- [ ] UAT section for Phase <N+1> filled in `<path>`
- [ ] <any plan-specific acceptance gate>

## Execution mode

Use **subagent orchestration** (Step 2 of the `execute-phased-plan` skill): decompose this phase into its tasks, dispatch one subagent per task (parallel where independent, sequential where dependent), receive task-level test reports, then run overall validation yourself before moving to Step 3. Each subagent must run and pass its task-level tests before its report is accepted.

## Branch + conventions

- Branch off `<base>`: `git checkout <base> && git pull && git checkout -b <type>/<short-name>`
- Conventional commits only (`feat(<scope>): ...`, `fix(<scope>): ...`)
- After last task: use the `ship` skill to push, review, merge, clean up.

## Key guardrails (from `CLAUDE.md` — enforce in reviews)

- <guardrail 1, verbatim from CLAUDE.md — e.g. "Never return `access_token_enc` from any endpoint">
- <guardrail 2>
- ...

## Environment / secrets

- `<ENV_VAR>` — <how to obtain, e.g. "from Supabase Vault; never commit">
- `<ENV_VAR>` — <value if user authorised inline sharing, or "see <secret store>">

## Deviations from plan (if any)

- <deviation in Phase <N> that affects Phase <N+1>, with reason>
- <or "none">

## Checkpoint at end of Phase <N+1>

Before handing over to Phase <N+2>, in this order:

1. Verify exit criteria (tests green, PR merged, UAT ticked).
2. Write a phase memory entry to `~/.claude/projects/<project-slug>/memory/phase_<N+1>_<short-title>.md` — outcome, key decisions, deviations, carry-forwards. Add a pointer line to `MEMORY.md`.
3. Produce the next handover prompt using the **`execute-phased-plan`** skill.
~~~

## Step 6: Hand off

Send the handover prompt and only the handover prompt — don't bury it under a chatty summary. One short lead-in ("Phase N done. Paste this into a fresh chat:") plus the fenced prompt. The user copies it into a new session and the next chat picks up with full, fresh context.

## Anti-patterns

| Anti-pattern | Why it burns the user |
|---|---|
| Starting Phase 1 in the chat that just wrote or reviewed the plan | That chat's context is already partially spent on brainstorming/spec/review noise. Importing it into execution corrupts Phase 1 from the start. Emit the Phase 1 handover first and let execution start in a fresh chat. |
| Starting the next phase because "it's just one more file" | Defeats the entire point — the user chose phase pacing for a reason. Stop at the boundary, always. |
| Handover prompt that says "see previous conversation for details" | Next chat has no access to this chat. If it's not in the handover, it doesn't exist. |
| Skipping exit-criteria verification before writing the handover | A handover that claims a red phase is green corrupts the next chat's assumptions for its entire duration. |
| Handover that names the wrong execution skill | User shouldn't have to re-plan in the next chat. Pick the skill deliberately, name it verbatim. |
| Leaking long secrets inline in the handover | Handover prompts get pasted around, often into shared notes. Reference the secret store, only inline values the user has explicitly authorised inline sharing for. |
| Summarising the plan instead of referencing it | The plan file is authoritative. The handover points at it; it does not replace it. |
| Rewriting the template to be "more concise" | The template's structure is what makes the next chat productive. Fill the sections; don't collapse them. |

## Composition with other skills

| Skill | Role |
|---|---|
| `superpowers:writing-plans` | Produces the phased plan that this skill then executes. If the plan isn't phased, suggest re-planning with phases before invoking this skill. |
| `superpowers:executing-plans` | Used *inside* each subagent's prompt — subagents follow this skill to execute their individual task. |
| `superpowers:subagent-driven-development` | Referenced by Step 2 orchestration model for parallel dispatch patterns. |
| `superpowers:verification-before-completion` | Enforced at Step 3 — no handover without fresh verification evidence. Also enforced per-subagent: each subagent must pass task-level tests before its report is accepted. |
| `superpowers:finishing-a-development-branch` / `ship` | The last activity of every phase — merge the PR, clean up local state, then write the phase memory (Step 4), then emit the handover. |
| `superpowers:writing-skills` | Irrelevant to runtime, but this skill itself was written with it. |

## When NOT to use this skill

- Single-phase tasks or small changes — just do the work, no handover theatre needed.
- Plans the user has explicitly said to auto-accept ("execute the whole plan, don't pause") — honour user instructions; they override the skill's default pacing.
- Experimental / throwaway work where context hygiene doesn't matter.

## Quick invocation phrases the user commonly uses

These all trigger this skill — recognise them and invoke immediately instead of asking for clarification:

- "execute the plan phase by phase"
- "do one phase then stop"
- "stop after Phase X"
- "do not carry on with Phase Y"
- "write a handover prompt"
- "give me a prompt for a fresh chat to continue"
- "write a prompt for a new chat to continue the plan"
- "pause at the phase boundary"
- (implicit) user has just finished brainstorming / writing / reviewing a multi-phase plan and says "ok let's execute" — default to emitting the Phase 1 handover first, not executing in the current chat
