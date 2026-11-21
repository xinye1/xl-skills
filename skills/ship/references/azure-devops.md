# Shipping on Azure DevOps (Azure Repos)

`SKILL.md` is written with GitHub's commands. When the repository's remote is on Azure DevOps, the
steps and gates are the same, and this file gives each step's commands and the places where the
host behaves differently. Read it once, before Step 0. `review-focus` reads the last section.

Everything here comes from shipping on Azure DevOps with the `az` CLI (the Concord project's
delivery kit, 2026-11); where something was not tried it says so.

## Set-up and names

- `az` with the DevOps extension, signed in: `az extension add --name azure-devops`, `az login`.
- Take the organisation, project and repository from the remote
  (`git remote get-url <remote>`):
  - `git@ssh.dev.azure.com:v3/<org>/<project>/<repo>`
  - `https://[<user>@]dev.azure.com/<org>/<project>/_git/<repo>`

  Below, `$ORG` is `https://dev.azure.com/<org>`. Most `az repos` commands take
  `--org $ORG --project <project>`; `az repos pr show`, `update` and `set-vote` take `--org` only.
  Shell variables don't carry over between Bash calls, so write the values out in full each time.
- The remote isn't always `origin`: use the one that points at Azure DevOps (`git remote -v`),
  written `<remote>` below. The base branch is the remote's default
  (`az repos show --org $ORG --project <project> -r <repo> --query defaultBranch -o tsv`), unless
  the project's shipping policy names another.
- Work items take the place of GitHub issues: put `#<id>` in commit messages and pass
  `--work-items <id>` when creating the PR. There is no `Closes #<n>` footer; whether completing
  the PR moves the work item is the project's choice (its policy says).

## Step 0: detect the state

```bash
az repos pr list --org $ORG --project <project> --repository <repo> --source-branch <branch> --status all --top 3 \
  --query "[].{id:pullRequestId,status:status,target:targetRefName,draft:isDraft}" -o table
az repos pr show --org $ORG --id <id> --query "{status:status,reviewers:reviewers[].{name:displayName,vote:vote},merge:mergeStatus}" -o json
az repos pr policy list --org $ORG --id <id> --query "[].{policy:configuration.type.displayName,status:status,blocking:configuration.isBlocking}" -o table
```

- `status` is `active`, `completed` or `abandoned`. The newest PR for the branch decides: an
  `abandoned` one means ask whether to reopen it or start a new one.
- Review decision: a reviewer's `vote` is `10` approved, `5` approved with suggestions, `0` none,
  `-5` waiting for the author, `-10` rejected. Any `-5` or `-10` is "changes requested"; an approval
  with none of those is "approved".
- Checks: the PR's policies stand in for `statusCheckRollup`. A build-validation policy is the CI
  run; `status` is `queued`, `running`, `approved` (passed) or `rejected` (failed). No policies
  listed means nothing gates the PR: treat it as "no CI".
- A merged PR's commits are reachable from `<remote>/<base>` when the project completes PRs as
  merge commits, so State D is: newest PR `completed`, and `git log <remote>/<base>..<branch>`
  empty after a fetch. If that log lists commits, they are new work.

## Step 4: when review runs

CI here is a build-validation policy on the target branch, not a workflow file, so look at the
policies rather than `.github/workflows`:

```bash
RID=$(az repos show --org $ORG --project <project> -r <repo> --query id -o tsv)
az repos policy list --org $ORG --project <project> --repository-id $RID --branch <base> \
  --query "[].{policy:type.displayName,enabled:isEnabled,blocking:isBlocking,settings:settings}" -o json
```

An enabled build-validation policy runs on every push to the PR's branch unless its settings say
it is queued by hand: treat the repository as **push-coupled** and review before the first push.
No build policy: **no CI**. Whether a draft PR holds a build back was not tried here: don't rely
on a draft as the merge gate.

Publish the review to the PR as a comment thread (next section), since there is no
`gh pr comment`.

## Step 5: push and open the PR

- **A description is at most 4,000 characters** (`az repos pr create` and `update` refuse more).
  So split the template in `pr-description.md`: the description carries `## Why`,
  `## For the reviewer`, `## Docs ↔ code`, and one line each for `## Test plan`, `## Review` and
  `## Verification`. The `## Docs` table, the `## Change map`, the full review record and the
  verifier's report go in the PR's first comment thread. Write the description to a file outside
  the repository and count it (`wc -m <file>`) before sending. If it is over, shorten each decision
  to one line with its link; never drop the `## Docs ↔ code` verdict or the `## Verification` line.
- **Link a doc at a commit** as
  `https://dev.azure.com/<org>/<project>/_git/<repo>?path=/<path>&version=GC<full sha>`
  (`GB<branch>` would follow the branch, which completing deletes). Give the repo path beside it.

```bash
D=<folder outside the repository>
git push -u <remote> <branch>
az repos pr create --org $ORG --project <project> --repository <repo> --source-branch <branch> --target-branch <base> \
  --title "<conventional title>" --work-items <id> --description "$(cat "$D/description.md")"   # add --draft true for a draft
```

Post the first thread already resolved, so it doesn't block completion. Set the status in the
body: a thread posted without one stays active and counts as unresolved. Build the JSON with
`json.dump`, so the text is escaped:

```bash
python3 - "$D/thread.json" "$D/review.md" <<'PY'
import json, sys
json.dump({"comments": [{"parentCommentId": 0, "content": open(sys.argv[2]).read(), "commentType": 1}],
           "status": "fixed"}, open(sys.argv[1], "w"))
PY
az devops invoke --org $ORG --area git --resource pullRequestThreads \
  --route-parameters project=<project> repositoryId=$RID pullRequestId=<id> \
  --http-method POST --api-version 7.1 --in-file "$D/thread.json" -o json
```

To refresh the description later: read it (`az repos pr show --org $ORG --id <id> --query description -o tsv`),
replace your sections, count it, and write it back with
`az repos pr update --org $ORG --id <id> --description "$(cat "$D/description.md")"`. A later round
of review or verification goes in a new resolved thread.

## Step 6: wait for CI

`az repos pr policy list` (above) shows the build's state; poll it rather than expecting a
`--watch`. A failed or expired build is queued again with
`az repos pr policy queue --org $ORG --id <id> --evaluation-id <evaluationId>`; a new push queues
it by itself. The build's log is in the pipeline run (`az pipelines runs show --org $ORG --project <project> --id <buildId>`).

## Step 7: merge

There is no `--match-head-commit`, and three things about the host matter here:

- **Take the PR's head from the fetched branch tip**, `git fetch <remote> <base> <branch>` then
  `git rev-parse <remote>/<branch>`, not from the PR's `lastMergeSourceCommit`, which lags a push
  while Azure DevOps recomputes the PR's merge.
- **A vote isn't tied to a commit.** Unless the branch policy resets votes on a new push, an
  approval given before a push still shows. So right before completing, fetch again and compare
  the tip with the commit the checks and the approval covered. If it moved, the new commits go
  back through review, CI and the docs ↔ code check first.
- **Never pass `--bypass-policy`.** If completion is refused because a branch policy isn't met (a
  required reviewer, a minimum number of reviewers that doesn't count the author), stop and report
  the policy's message. Who may approve is the project's rule, not something to work around.

```bash
az repos pr update --org $ORG --id <id> --status completed --squash false --delete-source-branch true
```

`--squash false` completes as a merge commit, as `SKILL.md` does on GitHub. Don't use
`--auto-complete`: like GitHub's auto-merge, it can complete a head pushed while it waits.
`--delete-source-branch true` is only for a feature branch: never when the source is a long-lived
branch (a release from `dev` into `main` would delete `dev`).

Recording your own approval is `az repos pr set-vote --org $ORG --id <id> --vote approve`. Do that
only where the project's policy has the author approve, and only after they said yes.

## Step 8: cleanup

As in `SKILL.md`. With merge commits, `git merge-base --is-ancestor <branch> <remote>/<base>`
after a fetch proves the branch is merged before `git branch -d`.

## Reviewing someone else's PR (`review-focus`)

- Read the PR: `az repos pr show --org $ORG --id <id> -o json`. Keep `sourceRefName` and
  `targetRefName` (drop their `refs/heads/` prefix) and `description`. The threads, where the
  author's `## Docs` table, change map and review record are:
  `az devops invoke --org $ORG --area git --resource pullRequestThreads --route-parameters project=<project> repositoryId=<repo> pullRequestId=<id> --http-method GET --api-version 7.1 -o json`.
- There is no `refs/pull`: fetch both branches, `git fetch <remote> <target-branch> <source-branch>`.
  The head is `git rev-parse <remote>/<source-branch>` and the base
  `git merge-base <remote>/<target-branch> <remote>/<source-branch>` (not `lastMergeSourceCommit`).
- Vote with `az repos pr set-vote --org $ORG --id <id> --vote approve` (`wait-for-author` or
  `reject` to ask for changes), and post the review text as a thread (the `POST` above), with
  `"status": "closed"` for an approval and `"active"` for a change request. A review can't be
  attached to the commit it checked, so read the PR again right before voting; a push after your
  approval is the author's to flag.
