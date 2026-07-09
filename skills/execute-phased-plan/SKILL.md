---
name: execute-phased-plan
description: Use when the user hands over an implementation plan with 3+ phases without explicitly asking for end-to-end auto-accept, or says "execute this plan phase by phase", "do one phase at a time", "stop after phase X", "don't carry on with the next phase", "pause after this one", or otherwise wants chat-level pacing on a long plan. Casual phrasing counts — the common thread is finishing one phase, stopping, handing off. Not for single-phase tasks; a request for just the handover prompt itself is the handover skill.
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

Default behaviour: once scope is confirmed, **immediately produce a handover prompt for the current phase** via the `handover` skill (see Step 3), then stop. Do not start implementing. The user pastes that prompt into a fresh chat, and that phase executes there.

Why this matters: if the user invoked you after brainstorming, plan-writing, spec review, or any other upstream work, that chat's context is already partially spent. Importing it into execution defeats the whole point of phase pacing. A fresh chat that *starts* from the handover prompt has exactly the context the phase needs — no more, no less.

**Skip this step and go straight to Step 2 only if** one of these is true:

- The user explicitly overrides: "execute here", "do it in this chat", "no handover, just run it", "I'm already in a fresh chat".
- The current chat is itself a handover-launched chat — detectable when the user's opening message closely matches the `# Handover —` template (in which case this IS the clean execution chat, just run the phase).
- The plan has a single phase and the user didn't ask for pacing — this skill shouldn't have triggered in the first place; proceed normally.

In all other cases, emit the handover and stop. If you're unsure, emit the handover and ask: "I've drafted the Phase N handover. Want to start Phase N in a fresh chat (recommended), or execute here?"

## Step 2: Execute the single phase via subagent orchestration

Unless the user chose **Manual** mode in Step 0 (they drive, you assist inline — the delegation gate doesn't apply), execute the phase by the shared execution model: **read `../handover/references/execution-model.md`** (sibling skill folder; the same text every handover prompt embeds — if the file isn't present because this skill was packaged standalone, use the execution model embedded in the incoming handover prompt) and apply it end to end. It is the single source of truth for the delegation gate, task decomposition with user validation, per-task subagent dispatch with explicit model-tier choice, report handling, and the orchestrator-run overall validation that gates the phase.

Two additions when running it from this skill:

- Include the repo's dev-loop conventions from `CLAUDE.md` in every subagent prompt (conventional commits, branch off base, PR → base). Merging and cleanup at phase end belong to the `ship` skill.
- While executing, keep three things close to hand:
  - **Exit criteria** for this phase from the plan (tests passing, PR merged, UAT green, whatever the plan states).
  - **Deviations from plan** — aggregate deviations reported by subagents, plus any discovered during overall validation. These go into the handover.
  - **Secrets / credentials** provided inline by the user — mark their origin so the handover can reference them without re-leaking them into git-tracked files.

## Step 3: Close the phase via `handover`

Once the execution model's overall validation is green, on a structurally heavy phase offer `nuclear-code-review` (consent-gated) before `ship` opens the merge gate — see `ship`'s own Step 4 for the same offer. Then run `ship` (merge the PR, clean up local state), then invoke the `handover` skill and let it run in full — it verifies the phase's exit criteria itself (its Step 2), writes the phase memory entry, and emits the next handover prompt. If its verification finds a red criterion, **stay in this chat and fix it** — never label a red phase complete; that lie corrupts the next chat.

**First handover only (from Step 1):** there is no verification evidence or deviations yet — mark those sections "N/A — phase not started".

Subsequent handovers are produced the same way by each executing chat. `handover` is the authoritative skill for all handover writing and its anti-patterns; this skill only sets the rhythm.

## Composition with other skills

| Skill | Role |
|---|---|
| `superpowers:writing-plans` | Produces the phased plan that this skill then executes. If the plan isn't phased, suggest re-planning with phases before invoking this skill. |
| `handover` | Owns everything at the phase boundary: exit-criteria verification, phase memory, the handover prompt and its anti-patterns. Its `references/execution-model.md` is also Step 2's orchestration model. |
| `ship` | The last activity of every phase — merge the PR and clean up local state before `handover` closes the phase. |
| `nuclear-code-review` | Optional gate for structurally heavy phases: offer it (consent-gated) before `ship` merges, so accepted restructurings land inside the phase instead of leaking into the next one. |

## When NOT to use this skill

- Single-phase tasks or small changes — just do the work, no handover theatre needed.
- Plans the user has explicitly said to auto-accept ("execute the whole plan, don't pause") — honour user instructions; they override the skill's default pacing.
- Experimental / throwaway work where context hygiene doesn't matter.
