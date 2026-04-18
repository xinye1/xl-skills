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
   - **Subagent-driven** (default) → subagent per task, each runs task-level tests and reports back; Claude runs overall validation (Step 2)
   - **Manual** (user will drive, Claude assists) → no subagent dispatch

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

1. **Decompose this phase into its tasks.** Look in the plan for an explicit task list for this phase. If the plan has one, use it verbatim. If it doesn't (the phase is described in prose, or the task list is vague), **draft a task list yourself from the phase's scope and deliverables, then stop and validate with the user** before dispatching any subagent — say something like: "The plan doesn't list explicit tasks for this phase, so I've drafted the following from the scope. Approve, or tell me what to refine." Once you have a list the user accepts, classify each task as independent (can run in parallel) or sequential (depends on another task's output).

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

## Step 4: Emit the handover and hand off

Once exit criteria are green, use the `handover` skill to produce and emit the phase handover prompt. The handover skill covers all remaining details:

- Writing phase memory entries (Step 3 of `handover`)
- Producing the handover prompt template (Step 4 of `handover`)
- Handing off cleanly (Step 5 of `handover`)
- Anti-patterns to avoid when handover writing

**Key difference for the first handover (Step 1):** The first handover has no "Verification evidence" or "Deviations" yet — mark sections as "N/A — Phase 1 has not started" or leave blank until the executing chat completes the phase.

**Next phase's handover:** The executing chat will use the `handover` skill to produce the Phase 2 handover once Phase 1 is complete. Do not reference `execute-phased-plan` for subsequent handovers — the `handover` skill is the authoritative tool for all handover writing and anti-pattern guidance.

## Composition with other skills

| Skill | Role |
|---|---|
| `superpowers:writing-plans` | Produces the phased plan that this skill then executes. If the plan isn't phased, suggest re-planning with phases before invoking this skill. |
| `handover` | Authoritative source for writing phase memory entries, producing handover prompts, and handover anti-patterns. This skill delegates all handover writing to `handover`. |
| `superpowers:executing-plans` | Used *inside* each subagent's prompt — subagents follow this skill to execute their individual task. |
| `superpowers:subagent-driven-development` | Referenced by Step 2 orchestration model for parallel dispatch patterns. |
| `superpowers:verification-before-completion` | Enforced at Step 3 — no handover without fresh verification evidence. Also enforced per-subagent: each subagent must pass task-level tests before its report is accepted. |
| `ship` | The last activity of every phase — merge the PR and clean up local state before invoking the `handover` skill to write phase memory and emit the next handover. |

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
