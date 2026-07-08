---
name: git-triage
description: Use when a working tree has accumulated untracked or uncommitted files that need resolving — the user says "resolve the untracked files", "why are so many files untracked?", "look at the uncommitted files", "should gitignore be updated?", or a status check reveals anything from a handful of stray files to a 10k-file explosion. Also use at session close-out when the tree isn't clean, or before a handover/ship when leftover files would confuse the next session. Not for routine committing of work just finished — that's the normal dev loop or `ship`.
---

# Git triage — resolve a dirty tree by classification, not bulk action

The standing instruction from the user: *"don't just commit — reason your planned actions, don't commit unnecessarily, and don't delete anything useful."* Triage is a classification exercise with a plan shown before anything destructive happens.

## Step 1 — inventory and diagnose

`git status --porcelain`, then group by directory/extension and count. Before touching anything, identify the *source* of each group:

- Work products of this or a past session that were never staged?
- Build/cache/data artifacts that should never be tracked?
- Output from a **parallel session or another worktree** (check `git worktree list` — sibling sessions drop files that look like strays here)?
- A **mass explosion (hundreds+)** — almost always one missing `.gitignore` pattern (a venv, `node_modules`, a data dump, an SDK dir), not hundreds of real files. Find the one pattern.

## Step 2 — classify every group, four buckets

| Bucket | Test | Action |
|---|---|---|
| **Track** | Repo would be broken/incomplete without it; a fresh clone needs it | Stage and commit with a proper message (follow repo conventions; separate commits for separate concerns) |
| **Ignore** | Generated, machine-local, or data — recreatable or environment-specific | Add a *pattern-level* `.gitignore` entry (not per-file), commit the gitignore change |
| **Delete** | Temporary/junk, duplicated or already-landed work | Delete — but only after confirming nothing references it and no parallel session owns it |
| **Keep local** | Valuable but must not enter git: secrets (`.env`), local config, large local data | Leave in place, ensure ignored, note its existence and location to the user |

Never `git add -A` a mixed tree. Never bulk-delete a group you haven't diagnosed.

## Step 3 — act, with the plan visible

Present the classification (counts per bucket, the reasoning for anything surprising) before executing deletions; tracked-file commits and gitignore fixes can proceed directly. Special cases:

- **Bloated status breaks tooling** — when 10k untracked files make git misbehave, ship the `.gitignore` fix *first and standalone* (straight to the working branch if the repo's conventions allow) to restore a usable status, then triage the remainder.
- **Secrets found in the tree:** confirm ignored, never commit, and flag to the user — especially if they were ever staged.
- **Ambiguous files** (can't tell if landed elsewhere): check `git log --all --oneline -- <path>` and the other worktrees before deciding; if still ambiguous, ask rather than delete.

## Exit criterion

`git status` is clean or intentionally short, every surviving untracked file has a stated reason to exist, and `.gitignore` prevents the same accumulation recurring. Say what you did per bucket in one compact summary.

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| `git add -A` + "cleanup" commit | Buries junk and secrets in history; the user explicitly forbids commit-without-reasoning. |
| Deleting strays that belong to a parallel worktree/session | Destroys another session's in-flight work. |
| Per-file gitignore entries for a systemic pattern | The explosion recurs on the next build/run. |
| Leaving "just a few" untracked files unexplained | They compound; next triage starts from a worse baseline and git tooling degrades. |
| Treating triage as optional at close-out | A dirty tree is ambiguity handed to the next session. |
