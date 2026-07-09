---
name: summarise-session
description: Use when the user asks to "summarise the session", "session summary", "wrap up", "close down the session", "retro", "anything worth highlighting", "anything notable", "how did the agents do?", or signals a session or phase is ending — even without the word "summary". Also use proactively right before a handover; the retrospective decides what the handover persists. The deliverable is a retrospective for the user about what they couldn't see, not a prompt for the next chat — that's handover.
---

# Summarise session — the reflective pass that closes a working session

This skill exists for one moment: a chunk of work is done (a phase shipped, a feature merged, a debugging session resolved), and before moving on, the user wants to understand *what actually happened* — not the deliverable, which they can see, but the things that only the agent who lived through the session knows. Where it got hard. What surprised you. How the subagents performed. What you'd carry forward. What's worth filing or remembering.

**Audience: the human, not the next agent.** This is the load-bearing distinction. The output is prose in the chat for a person to read and react to — not a file, not a copy-paste prompt, not a code block. Tune the register to the user (terse for an expert, more explanation for a newcomer; honour any `CLAUDE.md` style preference — e.g. "be concise, sacrifice grammar for concision").

**What this is NOT:** it is not `handover`. Handover is forward-looking — a self-contained prompt the *next chat* pastes in to continue work. This is backward-looking — a retrospective *this chat* gives the *current user* about the session that just happened. They are bookends, and they compose (see "Working with handover" below). If the user wants a prompt for a fresh chat, that's `handover`; if they want to understand and close out what just happened, that's this.

## What a good session summary covers

Go *beyond* "what was delivered" — the user can read the PR. The value is the meta-layer. Cover the sections below that have something worth saying, and **skip the ones that don't apply** (no subagents → no agent table; nothing went sideways → no "unexpected issues"). Concision beats completeness: a tight summary that surfaces three real things beats a padded one that lists ten obvious ones.

- **One-line outcome.** What shipped, where (branch/PR/commit), tests green. One line — they know the broad strokes; this just anchors the rest.
- **Subagent / orchestration performance** (only if subagents were used). A small table is ideal: per agent — task, wall-clock time, tokens, tool-call count, outcome. Then a qualitative read: did the decomposition hold up? Was the dispatch order (parallel vs sequential) right? Was the model tier right for each task? Did any agent need re-dispatching? This is the part no log captures and the user most wants for calibrating future runs.
- **What verification / review caught that the happy path didn't.** If an independent review or your own integration pass caught something the task-level tests missed, say so explicitly — it's evidence for *why* the belt-and-braces step earned its cost. (E.g. "tests passed because single-row cases don't exercise batch atomicity; the independent review caught it.")
- **Discoveries & unexpected issues.** Things you learned that weren't in the plan — a stale assumption, a schema quirk, a tool that behaved differently than expected.
- **Deviations & detours from plan.** Where you did something other than what the plan/handover said, and why. Include the cost of detours (time spent, dead ends).
- **Gotchas worth carrying forward.** Durable traps that will bite the next person/agent — the kind of thing that belongs in memory or a CLAUDE.md, not just this chat.
- **Plan / process updates.** Did the plan itself change, or *should* it? Did the handover that launched this session contain stale info worth fixing at the source?
- **Candidate follow-ups.** See below — this is the bridge to action.

## Gather evidence honestly — never fabricate the meta-layer

The whole point is an accurate picture, so the numbers and claims have to be real:

- **Timing / tokens / tool-counts** come from the subagent task-completion notifications you received during the session (`total_tokens`, `duration_ms`) and from your own observation. If you genuinely don't have a number, say "not captured" — do **not** invent plausible-looking figures. A fabricated 4.2min is worse than an honest "didn't track it".
- **Outcomes** (tests, merges, issue numbers) come from real command output and the actual session history — `git log`, `gh pr view`, the transcript. Cross-check before asserting "merged" or "green".
- **Orchestration quality** is your honest judgement, including the unflattering parts — if a subagent fabricated evidence, if a detour was self-inflicted, if a model tier was wrong, say so. A retrospective that only flatters the session is useless for calibration.

This mirrors the data-honesty discipline the rest of the work runs on: the summary is evidence too.

## Candidate follow-ups — surface, don't auto-action

The reflective pass naturally turns up things that *should* outlive the chat: a bug worth filing, a gotcha worth saving to memory, a plan worth amending, a stale handover worth fixing. **Surface these as candidates and let the user choose** — do not silently file issues, write memories, or mutate plans as a side effect of summarising. The user may know the bug is already tracked, want different wording, or want to skip it.

Present them as a short, explicit closing list — "two things you might want, neither auto-actioned: (1) file the X bug? (2) save the Y gotcha to memory?" — and then, **on the user's go-ahead, action exactly what they approved** (file the issue, write the memory, update the plan). This two-beat rhythm — surface, then action on confirmation — is the skill's most important habit: it respects that issue-creation, memory-writes, and plan edits each need a judgement call the user owns. (It also composes with any project rule about how state changes — e.g. a GitHub-event-loop convention, or filing bugs under a specific label.)

## Working with handover — the two-pass close-out

At a phase boundary in a long plan you often want **both** skills, in this order:

1. **`summarise-session` first — the reflective pass.** Make sense of what happened; surface the gotchas, deviations, and follow-up candidates.
2. **User actions the follow-ups** — file the issue, save the memory, amend the plan. (Done within this skill, on their go-ahead.)
3. **`handover` second — the forward pass.** Now the handover's "Deviations from plan", "Key guardrails", and the phase **memory entry** it writes are *informed by* what the summary surfaced — they carry forward the real findings instead of a sanitised version.

Division of labour, so they don't duplicate:

- **`summarise-session`** is *ephemeral and broad* — prose for the human, in this chat, including soft signal (how the orchestration felt, timing, what to calibrate next time). Its job is to help the human decide *what is worth persisting*.
- **`handover`'s phase memory** is *durable and narrow* — a structured `project`-type memory file for future agents. It persists the decisions/deviations/carry-forwards that the summary judged worth keeping.

So the summary is the sense-making step that *feeds* the handover's persistence step. Run standalone, `summarise-session` is also complete on its own — at the end of a one-off session with no next chat, the retrospective (+ any follow-ups actioned) is the whole close-out.

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| Restating the diff / re-listing what shipped | The user can read the PR. The summary's value is the meta-layer they *can't* see — spend the words there. |
| Emitting a copy-paste prompt or code block | That's `handover`. This is prose for a human to read in the chat, not a payload for the next agent. |
| Fabricating timing / token figures to look complete | Destroys the one thing the summary is for — an accurate picture for calibration. "Not captured" is the honest answer. |
| Only flattering the session | A retrospective that hides the self-inflicted detour or the subagent that mis-claimed evidence can't improve the next run. Include the unflattering parts. |
| Silently filing issues / writing memories while "summarising" | Each of those is a judgement call the user owns. Surface as candidates; action only on go-ahead. |
| Padding to hit every section | Skip sections with nothing real to say. Three true things beat ten obvious ones — especially for a concision-preferring user. |
| Duplicating the handover memory verbatim | The summary is broad and ephemeral; the handover memory is narrow and durable. The summary *decides* what the memory should hold, it doesn't pre-write it. |

## When NOT to use this skill

- Mid-task, with work still in flight — summarising belongs at a natural close (phase shipped, session ending), not as a status ping during execution.
- Trivial single-step exchanges — a one-line "done, merged" is the summary; don't ceremony it.
- When the user explicitly wants only the forward prompt — go straight to `handover`.
