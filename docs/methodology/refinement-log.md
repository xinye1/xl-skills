# Refinement log

Newest first. Each entry records what prompted the change, the evidence, what changed, what was considered and rejected, and what the pass caught along the way.

## 2026-11-19 — the PR description is written for a reviewer who approves the docs, not the code

**Trigger.** The user, who runs a team doing agentic delivery, described how PR review works there. One developer raises a PR and another approves it. The second "is impossible … to read all the code, so they are expected to understand enough to make decisions on approval or suggesting changes." So the PR body should carry, inline or by link, the docs written during the work: "the feature description, design, intent, decisions, answer to grilling questions". Their premise: "Assuming that the code changes have been done relatively faithfully based on the documentation, approving the documentation … should imply approval of the PR itself." A second reader is an agent reviewing the PR as a whole.

**What the skills did before.**

- `ship` Step 5's body had `## Summary`, which listed what changed, and nothing on why or what was decided. PR #50's body is typical: a good change log, but a reviewer couldn't tell which calls they were being asked to approve.
- Three places where docs failed to reach the reviewer:
  - `grill-into-design` kept the grill answers only in the chat. The spec recorded decisions, but not what was asked, or where the user overrode the recommended answer.
  - The `show-me-your-work` decision log lives on the author's machine (`~/.claude/decision-logs/`), so the reviewer can never open it.
  - Nothing checked the premise. No step compared the code with the docs, so "approve the docs" never actually covered the code.

**What changed.**

- New `skills/ship/references/pr-description.md`:
  - the premise and its two conditions: the docs cover the change, and the code follows the docs;
  - sizing: trivial changes skip it, and the rule says when a change needs a doc in the repo;
  - where the docs come from, in four places: docs the branch adds or changes, docs it follows without changing, the record of a design review, and docs outside the repo. Decisions held only in the decision log or the chat are copied into the repo docs;
  - the template, with fixed headings agents can rely on: `## Why`, `## For the reviewer` (decisions ranked by cost of reversal, linked to their doc section), `## Docs`, `## Docs ↔ code`, `## Change map`, then the existing test, verification and review sections. `## For the reviewer` caps the decisions at about seven, then lists assumptions made without asking, what's safe to skim, and where to look if the reviewer reads code. It and `## Why` fit on one screen; if they can't, the PR is doing too much and gets split;
  - the `## Docs ↔ code` section: a verdict line (COVERED, COVERED with differences, `not run (trivial: …)`, or `skipped at the user's instruction (…)`) and three lists: where the code differs from the docs, what was done but isn't in the docs, and what the docs promise that this PR leaves for later;
  - links: at the head commit, since merging deletes the branch, with the repo path beside each for an agent;
  - the brief for the docs ↔ code check. The check runs on the default model tier (`sonnet`), or `opus` for a large diff that spans many modules. It can run alongside the Step 3b verifier.
  - Decisions are ranked by what's costliest to reverse, then by money or risk, then by behaviour users see, then by internal structure, as in `review-focus`.
  - The docs section also links the `adversarial-review` log beside a spec. Docs outside the repo (an issue, a wiki page) are linked, and any decision the PR depends on is written into a repo doc too, quoting the source: an agent reviewer may not be able to open them, and the checker is given repo paths only.
- `ship` gains Step 3c before the first push:
  - It sizes the change and finds the docs.
  - It stops and offers to write a doc when the change needs one and has none. Only the user's explicit word skips this, and the skip is recorded.
  - It sends a fresh subagent with the diff range and the doc paths only, never a summary. The subagent reports decisions not implemented as written, and changes the docs don't cover.
  - Every gap is resolved before review is requested: update a stale doc, fix the code, or list the difference. The verdict covers the commit it ran on, like Step 3b's. A later fix that changes behaviour or structure means running the check again before the next push and before merging. A fix to formatting, comments or tests only doesn't.
- `ship` Step 5 builds the body from the template through `--body-file`. When it refreshes the body later, it keeps blocks other tools append (CodeRabbit's summary). With `--body-file`, gh no longer applies a repo's `.github/pull_request_template.md` by itself, so the sections are fitted into the template's headings.
- `ship` Step 7 needs a docs ↔ code verdict that covers the head. If the body changes after a teammate approved, they are told what changed. The summary table gains a column, and State A2 enters through 3b and 3c.
- `grill-into-design` records each answer in the spec as it lands. The spec leads with a short intent, keeps a grill record (quoting the user where they overrode the recommendation), and has a "Changes during implementation" section, which the docs ↔ code check feeds.
- `review-focus` covers the reviewer's side. Asked to review a teammate's PR, it:
  - treats the description as the author's claims;
  - checks that the docs ↔ code verdict covers the head, and runs the check itself if not;
  - gives the usual numbered guide, plus where the code and the docs part ways;
  - posts the review only on the user's word;
  - offers a correctness or structure review (`/code-review`, `nuclear-code-review`) when the user wants one, rather than folding it into the guide.

**Considered and rejected.**

- *Links only, or key messages only.* The user offered either or both. Links alone: most reviewers won't click, and an agent pays a fetch per doc. Key messages alone: the description gets long, and the detail isn't kept with the code. Both, split by purpose: the decisions go in the body, and the detail stays in the linked docs.
- *Letting the PR body be the record.* A body is edited and replaced, and isn't kept with the code. Decisions are written into the repo docs, and the body points at them.
- *Folding the docs ↔ code check into the Step 3b verifier.* They check different things (running the app, and comparing text with code), and one brief doing both would do each worse. They run side by side instead.
- *Giving the checker the draft description.* That is the author's framing. A checker told the intent in other words confirms it. It gets the docs and the diff, as `adversarial-review` and `nuclear-code-review` get only committed context.
- *A new reviewer-side skill.* `review-focus` already produces exactly this guide for documents someone signs off. A PR is that document plus a check, so it was extended instead. It can be split out if the PR part grows.
- *Changing `nuclear-code-review` or `adversarial-review`.* Both already treat committed docs as context they may question, and neither should read a PR body, which is author framing.

**What the first docs ↔ code check caught (this PR, on itself).** All of the behaviour the docs described was in the skills. Six details in the skills weren't recorded in the docs:

- the check's model tier;
- the four-level ranking;
- the review-log and outside-repo links;
- re-running the check after a fix;
- the `.github/pull_request_template.md` handling;
- `review-focus` offering other reviews.

In each case the code was right and the log was out of date, the case the reference calls the common one. This entry now records them.

**What review caught (CodeRabbit CLI, round 1: 5 findings, all fixed).**

- After gaps were resolved by updating a doc, nothing checked the updated doc. The check now runs a second time on the result, and stops there. A gap still open after that goes to the user. A doc edit that changes a decision also triggers a fresh run.
- `review-focus` could run the check against whatever branch was checked out, not the PR under review. It now fetches the PR's head and base and passes both commits explicitly. `ship`'s brief does the same.
- When the description is the doc, the checker had no doc to compare with. In that case it now gets the description's `## Why` and `## For the reviewer` sections, which is the doc the reviewer approves.
- `gh pr review <pr> --approve | --request-changes` read like a shell pipe, and copying it would post an approval. It is now two separate commands.
- A code fix made in Step 3c on a resumed PR, after review and CI had run, didn't go back through them. It now does.

**Round 2 (3 findings, all fixed).**

- When the description is the doc, editing it doesn't move the head commit, so an old verdict could pass for text the checker never saw. The verdict line now says the description was the doc, and an edit that changes a decision reruns the check.
- Step 7's resume gate sent a PR back through Step 3c only for code changes. It now does the same for a decision changed in a doc.
- Gap fixes weren't committed before the second check, so it could read a working-tree doc the PR never carried. They are now committed first.

**Round 3 (2 findings, both fixed).**

- An open PR with new local commits (State A3) was pushed before Step 3c ran on them. A3 now runs Steps 3b and 3c on commits that change behaviour, structure or a documented decision, then pushes and refreshes the body.
- When the description is the doc, naming the commit couldn't show a later edit to it. The verdict line now carries a short `sha256` of the checked sections, and the merge gate compares it.

The third docs ↔ code run also caught a slip in the round-2 fix. Splitting Step 7 into bullets had tucked "tell an approving teammate what changed" inside the last bullet, so it applied to one case only. It is now its own paragraph again.

Links now use the full commit SHA: `gh browse` with a short one gives a link that can become ambiguous.

**Round 4 (5 findings, all fixed).** The first round-4 run returned only cached findings, so it was rerun with `--fresh`. Four of the five were on the reviewer's side, which earlier rounds had barely touched.

- A resumed PR could have the reviewer sections but no verdict, and none of Step 7's cases sent it through Step 3c. A missing verdict is now a case.
- A decision taken from a doc outside the repo was quoted in the description only, where the checker can't see it. It now goes into a repo doc too.
- `review-focus` checked a verdict against the head commit only. When the description is the doc, it now compares the sections hash too.
- `review-focus`'s checker could read the docs from whatever branch the reviewer had checked out. It now reads each doc at the PR's head (`git show <headRefOid>:<path>`).
- A commit landing while the user weighed the guide could be approved unseen. Before posting, `review-focus` now checks that the head and hash haven't moved.

**The owner's rulings.** Four decisions were put to the owner: blocking when a needed doc is missing, decisions inline with links for detail, extending `review-focus` rather than writing a new skill, and leaving `nuclear-code-review` and `adversarial-review` alone. Their answer: "1 keep it, 2 ok, 3 ok, 4 ok."

**Port due.** delivery-guardrail carries spin-offs of all three (`ship`, `grill-into-design`, `review-focus`), so each should adapt this for Concord: Azure DevOps PR links and `az repos pr` in place of `gh`. That is for a session in that repository.

## 2026-11-19 — pstack is pinned; a new session says what's new and asks before moving the pin

**Trigger.** The delivery-guardrail session relayed a ruling from its owner: "pinned ref, bumped by PR. the same should be for xl-skills." That contradicted what the owner had told this session directly two days earlier ("just follow any updates from the source"), so nothing was changed on the relayed ruling; it was put to the owner here. Their answer: "pstack should be pinned. when an update is available the user (I) should be prompted with "whats new" and ask if they want to run an update on the pin to get the latest. xl-skill should be automatically applied as I would have been full aware of the implication of any changes to my projects when I made them."

**Evidence that auto-update was the wrong default.** By 2026-11-19, auto-update had already moved pstack from 0.15.43 (`e1cc031`, the version PR #49 was written against) to 0.15.44 (`e58dd04`). No one had read the change. It happened to be harmless: it changed setup-pstack's default model for a reviewer seat, plus one line of the Claude Code harness doc. But the next such change could have been to `create-verification-skill`, which `ship`'s gate runs.

**How the pin works (each step tested on this machine, 2026-11-19).**

- Claude Code's settings schema says a marketplace `ref` may be a full 40-character commit SHA. It was set on the `cursor-plugins` entry, with `autoUpdate` removed.
- Changing the `ref` alone broke pstack. `claude plugin list --json` showed: "Marketplace cursor-plugins is added but ignored. Its source doesn't match its extraKnownMarketplaces entry …", and pstack failed to load. `claude plugin marketplace add cursor/plugins#<sha>` re-cloned the marketplace at the pin ("Cloning repository … (ref: e1cc031…)"). `claude plugin update pstack@cursor-plugins` then moved the plugin back from 0.15.44 to 0.15.43, which loads without errors.
- Those steps are now one command, `pstack-pin.sh bump`, so a bump can't stop halfway.

**What changed.**

- New `skills/ship/scripts/pstack-pin.sh` (`check`, `check --hook`, `bump`, `skip`), with `test_pstack_pin.sh`: 45 checks against a fake upstream and a fake `claude`, all passing.
  - The "what's new" report lists:
    - the pstack commits since the pin;
    - the skills changed, added or removed, flagging those xl-skills uses;
    - whether the harness doc changed;
    - a compare link.
  - Run against the real upstream, it took 2.5 s and found the 0.15.44 change.
- A `SessionStart` hook (matcher `startup|clear`, so a chat begun with `/clear` and `/pickup` counts) runs `check --hook`, at most once a day. It speaks only when pstack has moved: a one-line notice for the owner, and context asking Claude to explain what's new and ask whether to move the pin. Added to `~/.claude/settings.json` on this machine; the README gives the entry.
- `ship` Step 3b's set-up check installs pstack at the recorded pin through `bump` (not `autoUpdate`), and offers the hook if it's missing.
- `docs/upstream.md` records the pin ("Pinned at"), the ruling, and how the pin works; the README install section matches.
- xl-skills itself stays unpinned. `~/.claude/skills` links to this checkout, so a merged change applies at once, as the owner asked.

**What review caught (CodeRabbit CLI, before the push: 3 findings, all fixed, each with a test).**

- A failed `marketplace add` or plugin update left the new pin in settings. The settings then pointed at a commit that wasn't registered (the state that stops pstack loading), and a later `check` would say "up to date". `bump` now restores the settings and re-registers the old source, and says so plainly if that fails too.
- `bump` failed on a machine with no `~/.claude/settings.json`, which is the fresh-install case `ship` uses it for. It now starts from an empty file, while malformed JSON still fails.
- The hook's `skip` read the latest change when it ran, not the one the owner was shown. A fetch between the two could silence a newer change unseen. The hook now writes the shown commit into the `skip` command.

**Second review (8 findings: 7 fixed, 1 not applicable).**

- *A plugin update can be a no-op.* Claude Code keeps the cached files when the version string hasn't changed. So `bump` now checks the commit Claude Code recorded (`gitCommitSha` in `installed_plugins.json`) and the installed `skills/`, `docs/` and `agents/` against that commit. On this machine, before the change, the installed files matched the pin exactly, apart from Claude Code's `.in_use` marker. On a mismatch it reinstalls, and if they still don't match, it rolls back.
- *A pin held as a branch or tag was rolled back to the default branch.* The rollback now re-registers whatever `ref` was there before.
- *Two bumps at once could undo each other.* `bump` holds a machine-wide lock from reading the old state to the end. It is a `mkdir` lock, because `flock` isn't on macOS.
- *The settings file could become world-readable.* The rewrite created a 0644 file even when settings were 0600, and settings can hold credentials in `env`. The temporary file is now created 0600, and the file's own mode is kept.
- *The hook's time limit didn't cover everything.* A blob-less clone fetches file contents on demand, outside the time limit. The private clone is now a full one (about 10 MB), so the report never touches the network.
- *`timeout` isn't on stock macOS, which the README supports.* The script falls back to `gtimeout`, or runs without a limit.
- *An install from before the pin (auto-update, no `ref`) passed `ship`'s "is pstack installed" check and stayed unpinned.* `ship` now asks to pin it.
- *Not applicable:* "docs/upstream.md has no Pinned at entry". The reviewer read GitHub's `main`, not the working tree, which has it.

**Third review (7 findings: 6 fixed, 1 not applicable, the same "Pinned at" one).**

- A rollback with no previous entry ran `marketplace remove` without `--scope`, which removes the marketplace from every scope, project scope included. It now passes `--scope user`.
- An update that changed the plugin and then failed was left installed. The rollback now reinstalls from the old pin whenever the installed commit isn't the one before the bump.
- Two sessions making the first clone at once shared a `.part` folder. Each now clones into its own temporary folder, and the first rename into place wins.
- The lock now works without `flock`. The test's permission check uses Python, not GNU `stat -c`.
- Writing the lock exposed a bug of its own. The `EXIT` trap named a `local` variable, which was gone by the time the trap ran, so the lock was never released and the next bump waited ten minutes. The tests hung, which is how it was found. The trap now expands the path when it is set.

**Fourth review (3 findings, all fixed).**

- `plugin update` picks the most specific installed scope by default. It now passes `--scope user`, like the other plugin commands.
- Git's rename detection would report a renamed skill only under its new name. A dependency renamed upstream would then not show as removed. The report's diffs now use `--no-renames`.
- An update could fail after changing the files but before changing the recorded commit. The rollback now also compares the files with the old pin.

**Final review, of the commit (1 finding, fixed).** The hook matched only `startup`. A fresh chat begun with `/clear` (how `handover` and `pickup` work) sends `clear`, so a long-lived Claude Code could go days without a check. The matcher is now `startup|clear`. The daily throttle keeps that to one notice. `resume` and `compact` are left out because they continue work already in progress.

**Re-review of the commit (5 findings, all fixed).**

- The rollback copied the whole settings file back. That would discard anything another session changed in the meantime, such as the model or another plugin. `bump` now saves only the `cursor-plugins` entry, and puts back only that entry.
- That entry is saved before settings change, and a failed save stops the bump. Before, a failed backup copy didn't stop it.
- The lock's `EXIT` trap quoted a path into shell code, which a `'` in the path would break. It now reads a global variable.
- A rollback compared the files with the old pin only when the old ref was a SHA. It now compares them with the commit that was installed, whatever the ref.
- A first install that registered and then failed was left installed. The rollback now uninstalls it.

**First bump, 0.15.43 → 0.15.44.** `check` reported one upstream change. It set Gemini 4 Neon as setup-pstack's default model for one reviewer seat, and updated the matching line in `docs/harness/claude-code.md`. None of the skills xl-skills uses changed. The owner approved ("yes"), and `pstack-pin.sh bump e58dd04…` ran on this machine:
- it re-added the marketplace at that commit;
- the plugin updated 0.15.43 → 0.15.44;
- the recorded commit and the installed files matched the pin;
- `~/.claude/settings.json` kept its mode.

"Pinned at" in `docs/upstream.md` now records it.

**Considered and rejected.**

- *Bump only through a PR, as the kit does.* The pin that takes effect is in user settings, which no repo holds. So the owner's yes runs `bump` at once, and the record in `docs/upstream.md` follows through `ship`.
- *Pinning by leaving `autoUpdate` off without a `ref`.* That freezes this machine. But a fresh install would get upstream main rather than the reviewed commit, and nothing would ever say an update exists.
- *Checking at every session start without a throttle, or in `ship` only.* The first adds a network call to every start. The second raises updates only when shipping, which may be days after they land.
- *Fetching into Claude Code's own marketplace clone.* That clone belongs to Claude Code, which re-clones it on `marketplace add`. The check keeps its own blob-less clone in `~/.cache/xl-skills/pstack-pin/`.

## 2026-11-17 — wiring in the rest of pstack where it fills a gap

**Trigger.** After PR #49, the user: "for similar skills (I assume e.g. show-me-your-work is similar to summarise-session?) then analyse pros and cons of each, plug any gaps with my own skills if beneficial, then wire in the new skills. don't blindly do so to confuse me and you when skills are invoked and/or abandon any skills that are currently working well."

**How it was judged.** Each candidate from the survey was read in full, in the installed pstack 0.15.43, beside the xl-skills skill it resembles. The pros, cons and verdicts are in [the report](../reports/2026-11-17-pstack-overlap.md). The rule that keeps invocation clear: no pstack skill gets a trigger of its own. Each one starts only from a named moment inside an xl-skills skill, or when the user types it, so a request never has two skills competing for it.

**On the user's guess.** `show-me-your-work` is not like `summarise-session`. It is a log kept *during* the work, while `summarise-session` is a retrospective written *after*. So the log was wired in to feed the retrospective, and nothing replaces it.

**What changed.**

- `handover` asks for a decision-log path for multi-phase or unattended plans (`~/.claude/decision-logs/<repo>/<plan-slug>.tsv`, outside the repo and `/tmp`). Both templates carry it. Each phase end audits the log before `summarise-session`. The from-disk check fails on an unfilled `<plan-slug>`.
- Both execution models (inlined into every handover): the orchestrator appends rows at decision points, in `show-me-your-work`'s format.
- `execute-phased-plan`: one log across a plan's phases. For a run the user won't watch, `show-me-your-work`'s end-of-run review runs on a different Claude tier from the orchestrator's (its "another vendor's model" has no Claude Code equivalent).
- `summarise-session` reads the log first for decisions. It also gains a "skill edit" candidate with `reflect`'s three filters, routed by owner: an xl-skills skill goes on a branch and through `ship`; a plugin skill is never edited and is named as an upstream issue; a rule a check could enforce goes to `correct`.
- `ship` Step 3b: a claimed measured number goes through `benchmark-checklist` or `principle-explain-the-number`. Step 4: an optional `blast-radius` offer for small diffs that touch something shared.
- `adversarial-review`: a finding a read-only command can show carries the command and its output (from `interrogate`).

**What review caught (CodeRabbit CLI, before the push: 4 findings, all fixed).**

- The report still said the decision log "must sit in a git-ignored folder". That is the PR #49 mistake again, in prose this time. It now says the log lives outside the repo.
- The number check sat inside the behavior gate, so a docs-only PR claiming a speedup skipped it. It now runs whenever a PR claims a measured number.
- "Faster or slower, with a limiter" doesn't fit a standalone eval score. A comparison and a standalone measurement now report different fields.
- A handover could name a decision log on a machine without pstack. The execution models now give the six columns as a fallback.

**Considered and rejected.**

- *Running `reflect` as written.* It copies the skill it edits into `~/.claude/skills`, which is this repo through the symlink. For a pstack skill, that is the copying the user ruled out on 2026-11-17, so its filters were taken instead.
- *Wiring `ketchup` into `status-report`.* Two skills would answer "where are we". `status-report` and `elii` already lead with the delta and the decision brief.
- *Running `interrogate`.* It is built on `arena` (several models and worktrees), and it would compete with `adversarial-review` for plans.
- *An untracked `decisions.tsv` in the work dir* (`show-me-your-work`'s default). Removing the worktree deletes it, the same lesson CodeRabbit taught on PR #49's evidence folder.
- *Wiring `sharpen`.* It is a prompt tool the user types, with no natural moment inside another skill.

## 2026-11-17 — poteto's pstack as a plugin; ship gains a verification gate

**Trigger.** The user: "there's a set of new skills we need to add, one around improving baseline linting and one about verification, following poteto's … advice." Their first answers were to copy and adapt pstack's `correct` and `create-verification-skill` ("Copy and adapt (Recommended)", "Both, one skill (Recommended)", "Generator + ship gate (Recommended)").

**Three course changes, in order.**

1. *Which repo.* Work began in the Concord delivery kit (delivery-guardrail), because the question spoke of "the kit". The user then said: "this is also being done to the concord project delivery-guardrail skills (spin-offs from this repo), so for future instances we should align both and make sure this repo updates on the skills on this level (applying all project), and the concord project one adapts changes as appropriate for the project." The kit worktree, which had no changes, was removed, and the work moved here. The rule is in [upstream.md](../upstream.md) and in Claude's project memory.
2. *Copies.* Adapted copies of both skills were drafted here, each with poteto's MIT licence. Additions were a "raise the baseline" path in `correct` (count each candidate rule's violations, turn it on, fix it, or ratchet it) and, in the generator, a Verdict section and a git-ignored evidence folder.
3. *Plugin instead.* The user, before anything was committed: "i think pstack should be directly downoaded as plugins, and my related skills such as `ship` should reference and invoke them. this way I won't need to worry about updating these skills myself, instead just follow any updates from the source." The copies were deleted. pstack was installed (`claude plugin marketplace add cursor/plugins`, `claude plugin install pstack@cursor-plugins --scope user`; version 0.15.43, commit `e1cc031`), and `"autoUpdate": true` was set on the `cursor-plugins` marketplace in `~/.claude/settings.json`.

**Why the plugin is better, and what it costs.**

- Gained: no copies to keep in step, and every upstream fix arrives on its own. That matches the user's aim.
- Lost: the "raise the baseline" detail in `correct` (upstream keeps one sentence: "If the pattern is already common, fail only when a change adds more"), and the generator's Verdict and evidence-folder sections. The parts the gate depends on now live in `ship`'s brief to the verifier, so the gate doesn't depend on the generator's wording.
- Risk: updates arrive unreviewed. The rule is to depend on a pstack skill's name and purpose, never its wording.

**How they are started.** A headless test (2026-11-17, `claude -p`) called the Skill tool on `pstack:create-verification-skill`. It refused: "cannot be used with Skill tool due to disable-model-invocation. Ask the user to run /pstack:create-verification-skill themselves". Every pstack skill but `setup-pstack` is set this way. So `ship` and `summarise-session` either have the user type `/pstack:<name>`, or, on their go-ahead, read the installed `SKILL.md` and follow it, after the plugin's Claude Code adapter. That is the route the adapter itself prescribes. The install path comes from `~/.claude/plugins/installed_plugins.json`, and the lookup command was run.

**What changed in this repo.**

- `ship` Step 3b, a verification gate before the first push. A fresh subagent that didn't write the change proves it in the real app. It uses the repo's `verify-<app>` skill. A set-up check blocks shipping when pstack or that skill is missing, until the user confirms setting it up. It returns `PASS` / `PASS+NOTES` / `FAIL`, which goes in the PR's `## Verification`. Merging (Step 7) needs a verdict that covers the head. State A2 enters through 3b, and the summary table has a Verify column. The independent-verifier rule and the verdict words are cited from pstack's Shipping playbook.
- `summarise-session` offers `/pstack:correct` when a correction repeats, instead of another memory line.
- README "Plugins these skills use"; [upstream.md](../upstream.md); `.gitignore` ignores `.worktrees/`.

**Considered and rejected.**

- *Letting ship go ahead, by hand, when the verification tooling is missing.* That was the first draft. The question was put to the user, and they ruled: "verification should become a standard step like code review, so any setup should have verify available, and if not then shipping should block and ask to confirm to install it." Their wording assumed the missing piece was pstack itself. The draft meant the repo's own `verify-<app>` skill. The ruling's principle is applied to both: shipping checks that pstack is installed on every run, and that the repo has a verify skill whenever the gate applies. Either one missing blocks and asks to set it up (install pstack, or generate the skill and commit it in this PR). The one way past is the user explicitly saying to ship without verification, recorded in the PR body as `skipped at the user's instruction`. That last escape is an inference from "ask to confirm", and the user was told so.
- *Keeping a thin own `correct` for the baseline detail.* That brings back the maintenance the user wants to drop. If upstream's one sentence proves too thin in use, the detail can come back as a separate skill that names `correct` and doesn't copy it.

**What the pass caught.**

- The ruff advice drafted for the copy was tested with ruff. `banned-api` with `msg` prints the fix in the error. The copy is gone, but the result shows upstream's "a lint whose error names the fix" works in ruff without custom code.
- Evidence inside a worktree: in a scratch repo, a git-ignored folder doesn't block `git worktree remove` and an untracked one would. The first draft put evidence in a git-ignored folder for that reason, but removing the worktree deletes the folder too, so the PR's evidence links would die. CodeRabbit caught it (below).

**What review caught (CodeRabbit CLI on PR #49: 4 findings, all fixed).**

- Evidence in a git-ignored folder inside the worktree is deleted with the worktree in Step 8. It now goes in a durable folder outside the repo (`~/verify-evidence/<repo>/<branch>/<run>/`), copied out if the repo's verify skill writes it inside.
- A changed path the verifier couldn't reach was only "reported", while Step 7 accepted `PASS+NOTES`, so an unverified path could merge. A new verdict, `INCOMPLETE`, doesn't pass Step 7. Only the user's explicit go-ahead to skip the path does, and the PR records it.
- New behavior that no feature file covers could pass undriven. The verifier now adds the missing feature file in the same PR and drives it, and never passes changed behavior it didn't drive.
- In a push-coupled repo, review (Step 4) runs before the first push, after the verdict. A behavior-changing review fix now needs re-verifying before the next push, not only before merge.

**Survey of the rest of pstack** (the user asked which other poteto skills fit their workflow). A read-only subagent read all 58 skills at `e1cc031`. Two of its claims were spot-checked: only `setup-pstack` lacks `disable-model-invocation: true`, and `unslop` rule 13 bans dashes. With pstack installed, all of them are now available by typing `/pstack:<name>`. The shortlist for wiring into these skills:

- `show-me-your-work`: a decision log for long or unattended runs, which `handover` could point at.
- `principle-explain-the-number` with `benchmark-checklist`: vetting a measured number.
- `reflect`: into `summarise-session`.
- `blast-radius`.
- `interrogate`'s "a finding survives only if a run proves it": into `adversarial-review`.
- `sharpen`.

**Still to do.** delivery-guardrail adapts this: whether the team installs pstack too, Azure DevOps commands, `guardrail:` names. A session working in that repository does it.

## 2026-11-13 — handover follows Anthropic's model-selection guidance

**Trigger.** Anthropic published ["Which Claude model should you build with? Fable, Opus, Sonnet, or Haiku"](https://claude.dev/blog/which-claude-model-should-you-build-with/) on 2026-11-09. The handover skill picks the next chat's orchestrator model and sizes its subagents, so it was checked against the post.

**Where the skill had drifted from the guidance.**

| Skill said | Guidance says | Evidence in the post |
|---|---|---|
| Default orchestrator `sonnet` | "start most work on Opus 5.5 at its default effort level, `medium`"; Sonnet 5.5 for well-scoped, spec-driven work | Task table: "Not sure yet: Opus 5.5, `medium`" |
| No effort level at all | Change effort before model; past `high`, move up a model at a lower effort instead | Opus 5.5 SWE-bench Pro: `medium` ≈ 2.5 points below `high` for ~70% of the cost; `xhigh` +1.4 points for 2.5× the cost |
| Fable "~2.5× opus", prices 1:2:4:10 (Haiku 4.5 $1 … Fable 5.1 $10) | Haiku 5.5 $0.10 (≤100K-token prompts, $0.50 above), Sonnet 5.5 $2, Opus 5.5 $4, Fable 5.2 $8 | Price table; confirmed on the pricing page on 2026-11-13 |
| `haiku` for "rote edits, boilerplate" | Small models for work "where a mistake is cheap to spot, like finding files, running tests and reading logs. Keep code edits and judgment calls on the main model." | Subagent section |
| Escalate by tier | Escalate by self-verification, then effort, then tier; or run at `low` and re-run failures at `high` | Opus 5.5 at `low` with failures re-run at `high`: ~97% for ~$0.17 a task, vs 95.3% for $0.29 at `high` throughout |
| (not covered) | The built-in Explore subagent runs on the session's model, not on Haiku | Subagent section |

**What changed.**

- `handover/SKILL.md` Step 4: the orchestrator is sized to the phase's shape. `sonnet` is for a phase whose tasks and executable exit criteria are already written down, which is also the shape Template A fits. `opus` is the default when unsure. `fable` is for major refactors, migrations, architecture planning, phases leading many subagents, long unattended runs, or when `opus` at `high` already fell short. A new effort rule: `medium` by default, `high` only on evidence, and never `xhigh` or `max` (recommend the next tier instead).
- The handover carries the effort in its frontmatter (`effort:`), header callout and receipt. The receipt always prints `/effort <level>`, and the closing line uses `claude --model … --effort …`. The from-disk check now fails on an unfilled `<recommended effort>`.
- Both execution models (`references/execution-model.md`, `references/execution-model-goal-directed.md`): current prices, `haiku` limited to read-and-report work, an escalation order (verification → effort → tier), the low-first re-run pattern, and explicit `model: haiku` for cheap exploration. The goal-directed version also notes that a lean orchestrator context matters more the bigger the model, because long runs bill mostly as cache reads.
- `pickup/SKILL.md`: lists the effort next to the model, adds `/effort` to the switch message and an effort reminder to the receipt, and treats a missing field (older handovers) as `medium`. Effort is not gated, because a chat can't reliably read its own effort level.

**Considered and rejected.**

- *Defaulting every orchestrator to `opus`.* The post's "start on Opus" is for unknown work. A phase from a written plan with explicit tasks is the spec-driven case it sends to Sonnet 5.5. So the rule keys on the phase's shape, and `opus` is the default only when that shape is unclear.
- *Sending Sonnet 5.5 the goal-directed Template B.* Nothing in the post says Sonnet 5.5 plans better without a procedure. Its advice to write "precisely enough for the most literal model" points the other way, so Template A stays.
- *Gating `/pickup` on effort as it gates on model.* The chat can't read its own effort reliably, so a gate would guess. The receipt shows it instead. Review then suggested that `/pickup` end its turn after the reminder until the user confirms effort. Rejected: that adds a turn to every hop, including the normal path where the handover receipt already had the user run `/effort` before `/pickup`, or start with `claude --effort`. The pickup reminder is the third safety net, not the first.

**What review caught (CodeRabbit CLI on PR #47).**

- The first draft printed `/effort` only for non-`medium` handovers, on the theory that `medium` is Claude Code's default. But `/effort` is saved per model (`modelSettings.<model>.effortLevel` in `~/.claude/settings.json`) and carries into later sessions. This machine has Opus 5.5 saved at `high`, so a `medium` handover would have silently run at `high`. The step is now always printed.
- The same-tier receipt branch still said to print only `/clear` and `/pickup`, contradicting the always-print rule. Eval 0 also expected the receipt to compare against the chat's current effort, which the skill says can't be read. Both fixed.
- The execution models said to leave subagent effort "at the model's default", but an Agent call without `effort` inherits the session's effort. Subagents now start at an explicit `medium`.
- Eval 0 still expected Template A's sections even when the new rules pick `opus`, which takes Template B. It now expects the sections of whichever template the recommended model takes.

**What the pass caught along the way.**

- `summarise-session/references/prices.json` had no `claude-fable-5-2` entry, so Fable 5.2 turns were reported as unpriced. Fixed in PR #46 with the pricing-page rates ($8 / $10 / $16 / $0.20 / $40; fast mode $16 / $80).
- PR #43's idle cache re-write pricing chose Haiku 5.5's prompt-length tier from the trimmed write, not the whole request. A 115K-token request was priced at $0.0075 instead of $0.0375. Fixed in that PR.
- Stale model prices outside handover: `adversarial-review/SKILL.md` called Fable "roughly 2.5×" Opus (it is 2× at Fable 5.2). Fixed in PR #48, which cites `prices.json` as the source.
