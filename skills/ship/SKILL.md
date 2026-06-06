---
name: ship
description: Ship code changes end-to-end: branch, commit, local tests, subagent code review, push, PR, CI, merge, and local/worktree cleanup. Use when the user says "ship it", "ship the code", "ship the changes", "let's ship", or asks to push/PR/merge current work. Also resumes mid-journey — committed-not-pushed, PR awaiting review, approved-and-ready, or post-merge cleanup — auto-detecting the stage. Merge-side counterpart to the superpowers dev-loop skills; prefer over ad-hoc git/gh commands.
---

# Ship — end-to-end code shipping

This skill owns the full path from local changes to merged PRs to clean local state. It hands off cleanly to and from the superpowers dev-loop skills (`using-git-worktrees`, `finishing-a-development-branch`, `requesting-code-review`, `receiving-code-review`, `verification-before-completion`) rather than duplicating or contradicting them.

The workflow is designed so that *any* starting state — uncommitted work, already-pushed PRs, a mix, or nothing to do — lands on the right entry point without the user having to specify.

## Step 0: Detect starting state

First detect the base branch (used by several signals below):

```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
# Fall back: dev → main → master
```

Then run in parallel:

- `git status --porcelain`
- `git branch --show-current` (returns empty on detached HEAD — see caveat below)
- `git rev-list @{upstream}..HEAD --count 2>/dev/null || echo "no-upstream"`
- `git rev-list "origin/$BASE..HEAD" --count 2>/dev/null` (commits beyond base — used to disambiguate A2 from a brand-new empty branch)
- `gh pr list --state open --author @me --json number,headRefName,baseRefName,title,reviewDecision,statusCheckRollup`
- `gh pr list --state merged --author @me --limit 10 --json number,headRefName` (then cross-check each `headRefName` against `git branch` to find local branches that survived a remote merge)

Classify and announce the detected state in one line (e.g. "Resuming at merge for #42 — approved + CI green") before proceeding:

| State | Signal | Entry point |
|---|---|---|
| **A. Uncommitted changes** | dirty tree (`git status --porcelain` non-empty), no open PR for current branch | Step 1 |
| **A2. Committed, not pushed** | clean tree on a feature branch with no open PR AND ((commits-ahead-of-upstream > 0) OR (`no-upstream` AND commits-beyond-base > 0)) | Step 4 |
| **A3. Iteration on existing PR** | dirty tree OR commits-ahead-of-upstream > 0, on a branch whose own PR is currently open | Commit any dirty work (Step 2 logic — reuse the existing branch) and/or push (Step 5 push only — PR already exists), then re-evaluate as B / B2 / B3 / B4 |
| **B. PR open, awaiting review** | clean tree, in sync with remote, open PR, `reviewDecision` is `null` or `REVIEW_REQUIRED` | Step 4 |
| **B2. PR open, changes requested** | clean + in sync, open PR with `reviewDecision: CHANGES_REQUESTED` | Step 4 — fix issues first, then re-review |
| **B3. PR approved, CI not green** | clean + in sync, open PR with `reviewDecision: APPROVED`, at least one check pending or failing | Step 6 |
| **B4. PR approved + CI green** | clean + in sync, open PR with `reviewDecision: APPROVED`, all checks passed (or `statusCheckRollup` empty — repo has no CI configured, treat as green) | Step 7 — skip straight to merge |
| **C. Mixed** | dirty tree, current branch has no open PR, but other branches do | Handle dirty tree through Steps 1–5, then loop open PRs from Step 4 at their own detected sub-state |
| **D. Post-merge cleanup** | `gh pr list --state merged` returns a PR whose `headRefName` still exists as a local branch | Step 8. If the user is currently *on* that branch and the tree is dirty, stop and flag — the work belongs on a fresh branch off base, not on a stale-merged one |
| **E. Nothing to do** | none of the above match (e.g. clean tree on base branch, no open PRs, no surviving post-merge branches) | Report "nothing to ship" and stop — no git operations |

**Resolution order when multiple states match — evaluate top-to-bottom and stop at the first match:**

1. **D** — clean up surviving merged-PR branches before anything else
2. **C** — multi-context work; iterate
3. **A3** — PR for current branch already exists; iteration loop wins over generic "fresh changes"
4. **A** — dirty tree, no PR for current branch
5. **A2** — clean + committed + not pushed
6. **B4** → **B3** → **B2** → **B** — most-advanced PR state wins (approved + green > approved + red > changes requested > awaiting review)
7. **E** — nothing matched

**Caveats:**

- **Detached HEAD** (`git branch --show-current` empty): `rev-list @{upstream}..HEAD` will fall through to `no-upstream`, which would otherwise misclassify as A2. Treat detached HEAD as E and flag — the user should check out a branch first.
- **Empty `statusCheckRollup`** for B4: a repo with no CI configured returns an empty array; treat empty-checks as green (the equivalent of "nothing to fail"). If the repo *should* have CI but the array is empty, that's a config bug — flag rather than merging blind.
- **Draft PRs + pre-merge-gated CI:** an open *draft* hasn't run the gated CI yet, so empty `statusCheckRollup` on a draft is **not** B4-green — never merge it blind. A null-review draft classifies as **B** and resumes correctly at review → gate (Steps 4 → 6). CI coupling itself (push-triggered vs pre-merge-gated) is determined in Step 4 and decides whether review runs before or after the push.

Why this matters: superpowers' `finishing-a-development-branch` (Option 2) ends after `gh pr create` — its job is done. Ship takes over from there. The granular detection is what lets the two flows compose without friction and lets the user invoke ship at any point in the journey.

## Step 1: Identify logical change groups (State A or C)

Run `git diff --name-only` and `git status`. Group files by subsystem so each group is a coherent, independently reviewable PR.

Typical groupings by repo area: frontend/dashboard, backend/api, database/migrations, infrastructure/ci, documentation. Use whatever subsystem boundaries the repo's directory layout suggests — don't force a taxonomy that doesn't fit.

Do *not* bundle unrelated concerns into a single PR to save effort. Two small focused PRs review faster and merge cleaner than one mixed one.

## Step 2: For each group — branch + commit

Detect the base branch from the remote default:

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's|refs/remotes/origin/||'
```

If that fails, fall back to `dev` → `main` → `master` in order.

Branch naming: `<type>/<short-description>` where `<type>` is one of `fix`, `feat`, `docs`, `ci`, `refactor`, `chore`, `test`, `perf`.

```bash
git checkout <base>
git pull origin <base>
git checkout -b <type>/<short>
git add <specific files>        # never -A or -. — keeps other groups' work out of this commit
git commit -m "<type>(<scope>): <imperative description>"
```

**Worktree awareness.** If `git rev-parse --git-common-dir` differs from `git rev-parse --git-dir`, the user is inside a `superpowers:using-git-worktrees` worktree. The branch already exists — reuse it rather than creating a new one. Remember the worktree path; you'll need it for cleanup in Step 8.

## Step 3: Run local tests + lint before push

This step exists to honor `superpowers:verification-before-completion`: no completion claims without fresh verification evidence. Pushing a red branch just to let CI catch it wastes a CI run and delays feedback.

Auto-detect the test command from repo markers:

| Marker | Command |
|---|---|
| `pyproject.toml` + `pytest` available | `pytest -x --ff` |
| `package.json` | `npm test --silent` (or `pnpm test` / `yarn test` if those lockfiles are present) |
| `Cargo.toml` | `cargo test` |
| `go.mod` | `go test ./...` |

Auto-detect lint similarly (best-effort — lint failure is not always blocking, but it's cheap to run):

| Marker | Command |
|---|---|
| `ruff` available + Python repo | `ruff check --fix <paths>` |
| `.eslintrc*` or `eslint.config.*` | `npm run lint` (or `eslint <paths>` if no script) |
| Rust repo | `cargo clippy` |

If tests or lint fail: fix the underlying issue, or revert the offending commit. Do not use `--no-verify`. Do not proceed past failure. If a pre-commit hook fails, fix it and create a *new* commit — do not `--amend` after hook failure (the commit didn't happen, so `--amend` would mutate the prior commit).

If no test command can be auto-detected, state that explicitly before pushing:

> No project test command detected — pushing without local verification.

Silent skipping is worse than no verification, because it lets future-you assume the tests ran.

## Step 4: Independent code review

Review is **mandatory before every merge** — ship never merges code that hasn't been independently reviewed. What changes is only *when* review runs relative to the push, and that's set by one repo fact: **does CI run on push, or only at a merge gate?** Determine it once, from the workflow triggers:

```bash
grep -REn 'on:|push:|pull_request:|types:|synchronize|ready_for_review|merge_group|workflow_dispatch' .github/workflows/ 2>/dev/null || echo "no workflows — no CI"
```

| CI coupling | Signal in `.github/workflows` | Push cost | Review timing |
|---|---|---|---|
| **Push-coupled** | fires on `push:` to the base branch, or `pull_request` whose `types` include `synchronize` (the default when `types` is omitted) | every push = 1 CI run | **pre-push** |
| **Pre-merge-gated** | `pull_request` `types` limited to `ready_for_review`, and/or `merge_group`, and/or `workflow_dispatch` — **no** `push`/`synchronize` | free | **post-push** |
| **No CI** | no workflows (`statusCheckRollup` empty in Step 0) | free | post-push (simplest) |

**The invariant, all three:** a review-driven fix must never trigger a CI run that the first push already paid for.

- **Pre-merge-gated / no CI → review post-push (the default, simplest path).** Push is free, so push first — Step 5 opens the PR **as a draft** when CI is gated — then review the PR diff (`gh pr diff <pr>`), fold fixes with more free pushes, loop to `APPROVE`. Only then open the merge gate (Step 6): that one action is the single CI run, on already-reviewed code. Interruptions and resumes are harmless here — a resumed review just costs free pushes, never a wasted run.
- **Push-coupled → review pre-push.** Each push costs a run, so review the **local diff before the first push** (`git diff origin/<base>...HEAD`, or the working tree for uncommitted work — the CodeRabbit CLI reads the local repo directly via `coderabbit review --base origin/<base> --type committed|uncommitted|all`, no PR needed), fold fixes into the commit(s), then push once (Step 5). This is the best a push-coupled repo allows, and it is fragile: resuming an already-pushed PR (States B/B2) forces a post-push review, and a fix then costs a second run. **If that recurs, convert the repo to pre-merge-gated CI** — drop `push`/`synchronize` so CI fires only at the gate. Fix the coupling at the source instead of choreographing around it.

**Order of Steps 4–6 by coupling:** push-coupled = **4 → 5 → 6** (review, then push, then CI); gated / no-CI = **5 → 4 → 6** (draft-push, then review, then open the gate + CI).

**Primary reviewer:** `coderabbit:code-reviewer` (runs the CodeRabbit CLI — a separate inference process *plus* deterministic static analysis, so it is genuinely **independent** of a Claude coding agent that authored the code). The CLI reviews **local** changes directly — no PR or push needed — which is what lets the push-coupled path review pre-push. **Fallback:** `feature-dev:code-reviewer` if coderabbit is unavailable — but treat this as a **degraded gate, not an equivalent**: it is a *same-model* reviewer (a Claude subagent reviewing Claude-authored code), so it produces correlated findings and cannot catch failure modes that Claude-class models systematically miss. When the fallback is the only reviewer, lean on the repo's deterministic checks (Semgrep / secret-scan / linters) as the independent backstop and weight the human merge decision accordingly.

Run **one** primary reviewer per change set — stacking same-model reviewers adds no rigor (correlated verdicts, not independent ones). Independence requires a different inference stack or deterministic tools, not a second same-model pass.

Dispatch with the **diff under review** (the local diff pre-push, or `gh pr diff <pr>` once a PR exists — *not* the working tree once pushed; pass the PR number when it exists) and require a structured verdict: `APPROVE` or `REQUEST_CHANGES` + issue list. When a PR exists, also have the reviewer leave inline comments via `gh pr review --comment`.

**Consuming the reviewer's output — apply `superpowers:receiving-code-review`:**

1. **Verify each reviewer claim against the diff under review before acting** — the local diff (`git diff origin/<base>...HEAD`) pre-push, or `gh pr diff <pr>` once pushed. Subagent reviewers sometimes read the wrong tree, producing false alarms about code that isn't actually in scope. Cross-check every non-trivial comment against the actual diff.
2. **Push back with technical reasoning when a comment is wrong.** Don't implement feedback just to seem cooperative.
3. **No performative agreement.** Never write "you're absolutely right", "great catch", "thanks for catching that", or similar. Just fix it, or just push back — the code change itself is the acknowledgment.
4. **One issue at a time, test each fix.** Clarify unclear items before implementing anything.

**On real findings:** fix → fold in (gated / no-CI: push to the branch — free; push-coupled: amend or add a fixup commit, stays local) → re-review the updated diff → loop. On `APPROVE`, continue — gated / no-CI: Step 6 (open the gate); push-coupled: Step 5 (push) if not yet pushed, else Step 6.

## Step 5: Push + create PR

When this runs, and whether the PR is a draft, follows the CI coupling from Step 4:

- **Pre-merge-gated CI:** push *before* review and open the PR **as a draft** (`gh pr create --draft`) — the draft push does not open the merge gate, so no CI fires yet. You'll review post-push (Step 4) then flip it ready in Step 6.
- **Push-coupled CI:** review already happened pre-push (Step 4), so create the PR normally — this first push is the only CI trigger as long as you don't iterate post-push.
- **No CI:** create normally; nothing is triggered either way.

```bash
git push -u origin <branch>
gh pr create [--draft] --base <base> --title "..." --body "$(cat <<'EOF'
## Summary
- <bullet of the main change>
- <bullet of secondary change if any>

## Test plan
- [ ] <verification step>
- [ ] <verification step>
EOF
)"
```

If the repo has `.github/pull_request_template.md`, gh applies it automatically — keep the body aligned with its section headers rather than overriding.

Stash the PR number for Steps 6–8.

## Step 6: Open the merge gate + wait for CI

How CI gets triggered depends on the coupling from Step 4:

- **Push-coupled:** the Step 5 push already triggered CI — just watch it.
- **Pre-merge-gated:** the gate is what fires the single run. **Invariant for *when* to open it:** only after local tests (Step 3) and review (Step 4) pass *and* you intend to merge — never before review (that wastes the run). The exact moment is a judgement call, not a fixed ritual. Mechanism options:
  - `gh pr ready <pr>` (draft → ready) — cheapest, keeps the PR's path-filter, but *overloads* GitHub's "ready for review" as the CI trigger (fine when no human is waiting on the draft→ready signal).
  - `gh workflow run <ci.yml> --ref <branch>` (`workflow_dispatch`) — keeps "ready for review" as a human signal, but runs the full suite (no PR diff base → no path-filter, more minutes).
  - enqueue to the merge queue if the repo gates on `merge_group`.
- **No CI:** `statusCheckRollup` is empty — nothing to wait for; go to Step 7.

```bash
gh pr ready <pr>          # gated CI: draft → ready triggers the one run (or: gh workflow run / enqueue)
gh pr checks <pr> --watch
```

On failure: inspect logs (`gh run view --log-failed` for the failing run), fix the root cause, then re-trigger exactly one run — push-coupled: push (reruns automatically); gated: flip back to draft (`gh pr ready --undo <pr>`), fix, mark ready again. Don't merge with red CI.

## Step 7: Merge

When the subagent verdict is `APPROVE` **and** all CI checks are green:

```bash
gh pr merge <pr> --merge --delete-branch
```

For pre-merge-gated CI you can let GitHub merge the moment the gate goes green: `gh pr merge <pr> --auto --merge --delete-branch` (needs the repo's *Allow auto-merge* setting; otherwise merge manually once Step 6 is green).

The `--delete-branch` flag removes the remote branch. Step 8 removes the local branch and any worktree.

## Step 8: Local cleanup

This mirrors `superpowers:finishing-a-development-branch` Option 1 (local merge + cleanup), except the merge already happened on GitHub via a regular merge commit. The cleanup itself is the same:

```bash
git checkout <base>
git pull origin <base>           # picks up the merge commit
git branch -d <merged-branch>    # safe delete
```

Use `-d`, not `-D`. If safe-delete refuses ("branch not fully merged"), that means `git pull` didn't pick up the merge commit — don't force. Investigate: check `gh pr view <pr> --json mergeCommit`, verify you're on the right base, verify the remote branch really got deleted. A stuck safe-delete usually indicates a real problem, not friction to bypass.

**Worktree cleanup.** If the work happened in a worktree (detected in Step 2):

```bash
git worktree remove <worktree-path>
```

If the worktree has uncommitted changes for some reason, this will refuse — investigate rather than `--force`.

## Step 9: Summary

Report a one-table summary of everything shipped this invocation:

| Branch | PR | CI | Review | Merge | Local cleanup |
|---|---|---|---|---|---|
| fix/foo | #42 | ✓ | APPROVE | merged | branch+worktree removed |

## Rules

- Never push to `main` directly. Never force-push to `main`.
- `dev` (or the default base) accepts direct commits only for genuine hotfixes where the PR-review loop is inappropriate — rare.
- Never skip hooks (`--no-verify`), bypass signing, or amend after a hook failure.
- Always `git add` specific files, never `-A` / `-.` — those grab files that belong to the next group.
- CD to production happens when the base branch merges into `main` via a separate PR — that's a different ship invocation.

## Integration with superpowers skills

| Superpowers skill | How ship interacts |
|---|---|
| `using-git-worktrees` | Step 2 detects and reuses the worktree's branch; Step 8 removes the worktree after merge. |
| `finishing-a-development-branch` | Steps 7 + 8 inline that skill's Option 1 cleanup. State A covers the "push + create PR" path (Option 2). State B is the explicit resume-point when that skill has already completed Option 2 and handed off. |
| `requesting-code-review` | Step 4 owns review dispatch; review is mandatory before every merge. Timing follows CI coupling (Step 4): pre-push when CI runs on push, post-push (free) when CI is gated pre-merge. Uses `coderabbit:code-reviewer`, not `superpowers:code-reviewer` — single primary reviewer per change set. |
| `receiving-code-review` | Applied in Step 4 when consuming the reviewer's verdict: verify before implementing, push back with reasoning, no performative language. |
| `verification-before-completion` | Step 3 (local tests + lint before push), Step 6 (CI green before merge), Step 8 (safe-delete refusal treated as a real signal, not friction). |

These skills are complementary, not redundant: superpowers covers the local dev loop and the "implementation complete, what next" decision point; ship covers everything downstream of that — the remote PR lifecycle and the loop-closing local cleanup.
