# Shipping policy: the default

`ship` uses this policy when the project has none of its own (SKILL.md, "Before Step 0"). It states
the defaults the skill's steps already apply, so it adds no rule and makes nothing stricter. Unlike a
project's policy, it can be directed otherwise from inside a session, wherever SKILL.md itself
allows that (the "skipped at the user's instruction" paths). Step numbers refer to `ship`'s SKILL.md.

It is also the template for a project's own policy. Copy it to `docs/ship-policy.md`, a "Shipping
policy" section in `CLAUDE.md`, or a plugin's `ship-policy` skill, and change what differs. What a
project's policy leaves out falls back to the skill.

## Who approves
- No person's approval is required before merging. The PR merges once Step 7's conditions hold.
- If a teammate has approved and the description then changes, tell them what changed (Step 7).

## Which reviewers gate a push
- Review is mandatory before every merge, and can't be skipped (Step 4).
- One primary reviewer: the CodeRabbit CLI through `scripts/cr_review.sh`. `feature-dev:code-reviewer`
  is a degraded fallback when CodeRabbit is unavailable (Step 4).
- Review runs before the push when CI runs on push, and after a draft push otherwise (Step 4).
- The loop stops after three rounds, as Step 4 says.

## Which gates may be skipped
- Local tests and lint: never skipped, no `--no-verify` (Step 3, Rules).
- Verification: not applicable to docs, tests, comments, lint or CI config only. Otherwise skipped
  only when the user explicitly says so, recorded in the PR body (Step 3b).
- Docs: `none needed` for a trivial change. Otherwise skipped only when the user explicitly says so,
  recorded in the description (Step 3c).

## Conventions
- Base branch: the remote's default, else `dev`, `main`, `master` in that order (Step 2).
- Branches `<type>/<short-description>`; commits `<type>(<scope>): <description>`; `git add` names
  files (Step 2, Rules).
- Merge commits, the remote branch deleted, at the checked head, no auto-merge (Step 7).
- Local cleanup with `git branch -d`, never `-D` (Step 8).
- pstack is installed and pinned in the user's settings by `scripts/pstack-pin.sh` (Step 3b).

## How a release reaches `main`
- Never push to `main` directly or force-push it (Rules).
- A release is its own PR from the base branch into `main`, a separate `ship` run through the same steps, started by asking for one (Step 0, state R; Rules).
- The base branch is never deleted: its Step 7 merges without `--delete-branch`, and Step 8 doesn't run (Rules).
- Direct commits to the base branch only for a genuine hotfix, rarely (Rules).

## How work is tracked
- A PR that delivers a tracked issue ends with `Closes #<n>`, one line per issue, plus the feature
  parent when it completes one (Step 5).
- A tracking issue or work item is not compulsory. When the work has none, say so, ask the user
  once to confirm, and record it in the description (Step 5).
- The merge closes the issue, never `gh issue close` (Step 5).
