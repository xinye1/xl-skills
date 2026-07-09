---
name: cross-session-brief
description: Use when coordinating with a PARALLEL peer session (another live Claude chat working the same repo/program) with the user acting as the messenger between them — signals include "write this up for a parallel session", "the other session has this update for you", "produce a plan for a different session to critique", "so I can update the other session", "let the other agent carry on?", or "the other session has finished, close out this session". Covers writing briefs for peers, consuming updates from peers, resolving overlap when two sessions converge on the same work, and closing out when a peer finishes. Not for sequential continuation in a fresh chat — that's `handover`.
---

# Cross-session brief — coordinating parallel peer sessions

`handover` passes the baton forward to a successor; this skill coordinates *sideways* with a live peer session that has its own context, its own worktree, and no access to this chat. The user is the message bus — everything exchanged must survive that hop.

## Writing a brief for a peer

A brief is a **bounded work order or evidence pack, not a context dump**. It contains:

1. **Standing state:** what this session has done, decided, and has in flight — enough that the peer doesn't re-derive or re-investigate it.
2. **The ask:** exactly what the peer should do (critique this plan / take this approach as default / implement X), and what form its answer should take.
3. **Scope fence:** what the peer must *not* touch because this session owns it — the explicit guard against two sessions doing the same job (it has happened: two sessions independently investigating the same crash).
4. **Reachable references:** absolute paths the peer can actually open. Worktree-aware — a path inside *this* session's worktree or scratchpad may not exist in theirs; prefer repo paths on a pushed branch, memory files, or shared docs. Screenshots/artifacts in a private worktree are unreachable — copy them somewhere shared or describe them.

Deliver as a file (repo doc or scratchpad) and give the user the path, or as paste-ready markdown if they're carrying it by hand. Assume zero shared chat context.

## Consuming a peer's update

Treat it as **evidence to reconcile, not instructions to obey**: check it against your own in-flight state, flag contradictions with what you know, and adopt what survives. If the update reveals overlap ("looks like you were doing the same job"), decide explicitly — continue here, yield to the peer, or split the work — based on who is further along and who owns the relevant worktree/branch. State the decision; don't silently duplicate.

## Shared state beats chat relay

When both sessions have repo access, prefer durable channels over paste-through: **memory files** (update memory *before* the peer plans, and say you have), pushed branches, spec/plan docs in the repo. The user relaying paragraphs is the fallback, not the default. When asked to "update memory so the other session can start planning", that is the whole deliverable — write it, confirm the path.

## Close-out on "the other session has finished"

1. **Verify what it landed** — git log/PRs/memory, not just the user's summary.
2. **Reconcile** — does anything this session was holding (follow-ups, stale status lines, memory entries) need updating or cancelling now?
3. **Release** — kill monitors/background jobs this session armed that the outcome makes moot; leave the worktree clean (`git-triage` if needed).
4. Then close normally (`summarise-session`, and `handover` only if there's a successor).

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| Brief that assumes chat context ("as discussed above") | The peer has no "above"; the brief is all it gets. |
| Paths into this session's private worktree/scratchpad | Peer can't open them; the user discovers this mid-relay. |
| No scope fence | Two sessions burn tokens doing the same investigation. |
| Blindly executing a peer's update | Peer context may be stale or wrong; reconcile against local evidence first. |
| Close-out that only says "ok" | Un-released monitors, stale memory lines, and dirty trees leak into the program state. |
| Relaying via chat what belongs in memory/repo | The durable channel survives both sessions; the chat paste doesn't. |
