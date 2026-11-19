# The PR description: written for a reviewer who won't read all the code

A teammate reviews and approves the PR. They can't read every line, and aren't expected to. They decide from the description, so it carries the documents written during the work: what the change is for, the design, the decisions and why they were made, the answers given in grilling.

**The premise.** If the code does what the docs say, approving the docs approves the PR. The docs are much shorter and easier to read than the code. This holds only when two things are true, and the description shows both:

1. **The docs cover the change.** Every decision the reviewer should weigh is written down, and the description brings it to the top.
2. **The code follows the docs.** A fresh agent compared the diff with the docs (the docs ↔ code check, below), and every place they differ is listed.

If either is missing, approving the description doesn't approve the code. The reviewer then has to read the code, which is what the description exists to spare them.

**A second reader: an agent reviewing the PR.** This might be the teammate's own Claude session, `review-focus` run on the PR, or the CodeRabbit app. The agent reads the description before the diff to learn what the change is meant to do. So the description uses fixed headings, and gives repo paths the agent can open as well as links. The agent should treat the description as the author's claims, and check them against the code.

## Size the description to the change

| Tier | When | What it carries |
|---|---|---|
| **Trivial** | A typo, a dependency bump that changes no behaviour, or a one-line fix whose cause the commit message states | `## Why` (one line) and `Docs: none needed (<reason>)`. No docs ↔ code check. |
| **Everything else** | Any other change | The full template below. |

**When a change needs a doc in the repo.** A change needs one when it contains a decision a reviewer should weigh:

- a new feature or a change in behaviour;
- a design or architecture choice;
- a new dependency;
- a change to a contract (a schema, an API, a config format, a wire format);
- a restructuring across modules;
- a bug fix whose cause isn't obvious (the diagnosis is the decision).

When the whole story fits in the description, as with a bug's diagnosis or a small change's one decision, the description can be the doc. When it doesn't fit, the doc goes in the repo, and the description surfaces its key points and links to it.

## Find the docs

Look in four places:

- **Docs the branch adds or changes:** `git diff --name-only origin/<base>...HEAD -- docs/ '*.md'`. These are specs, plans, ADRs, reports, method notes and refinement-log entries, and the repo's `docs/INDEX.md` if it keeps one.
- **Docs the work follows but didn't change:** the spec or plan the branch implements, and the ADRs it relies on. Commit messages, the plan, the handover and the session name them.
- **The record of a design review.** This means the spec's grill record, which `grill-into-design` writes, and the review log next to a spec (`<spec>.review.md`, from `adversarial-review`).
- **Docs outside the repo:** an issue, a Claude Doc, a wiki page. Link them, and quote any decision the description depends on. An agent reviewer may not be able to open them.

Some decisions are written down only where the reviewer can't see them. Write these into the repo docs before the PR, so the reviewer approves the same record the code was built from. Use the spec's "Changes during implementation" section, an ADR, or the plan.

- **The decision log** (`~/.claude/decision-logs/<repo>/<plan-slug>.tsv`, kept by `handover` and `execute-phased-plan`) is on the author's machine. Copy in the rows a reviewer should weigh.
- **Decisions made only in chat**, such as grill answers that never reached the spec, or a ruling the user gave mid-work. Write them up from the session, and quote the user's words where they ruled. Don't reconstruct what this session never saw.

Copying them into the description alone doesn't count. A description is edited and replaced, and isn't kept with the code.

## The template

Use these headings in this order. Agents rely on them. If the repo has `.github/pull_request_template.md`, fit these sections into its headings instead of replacing them.

```markdown
## Why
<Two to four sentences: the problem, who has it, and what changes for them. Take it from the spec's
intent. This is not a list of files.>

## For the reviewer
<One line on what approving means, e.g. "Approve if you agree with decisions 1–3. The code follows
the docs (see Docs ↔ code).">

Decisions to weigh (most consequential first, at most about seven):
1. **<the decision, in a few words>**: <what was chosen>, because <why>. Rejected: <the alternative>,
   because <why>. Reversal cost: <low | high, and why>. [<doc § heading>](<permalink#anchor>)
2. …

Assumptions made without asking: <one line each, or "none">
Safe to skim: <parts that follow mechanically from the decisions, such as tests of documented
behaviour, generated code or renames>
Worth a look if you read code: <one to three files or hunks where the risk concentrates, and why>

## Docs
| Doc | What it covers |
|---|---|
| [<title>](<permalink>) `<repo path>` | <e.g. intent, design, grill record> |

## Docs ↔ code
<COVERED | COVERED, with the differences below | not run (trivial: <reason>) |
skipped at the user's instruction (<reason>)> at <short sha>, by a fresh agent
- Differs from the docs: <what, why, and the follow-up issue>, or "none"
- Done but not in the docs: "none" (each one found was written into a doc: <which>)
- In the docs but not in this PR: <what, and where it will happen>, or "none"

## Change map
- <decision or doc section> → `<path>`, `<path>`

## Test plan
- [ ] <check>

## Verification
<Step 3b's verdict, as SKILL.md Step 5 gives it>

## Review
<Step 4's reviewer, rounds and outcome>

Closes #<issue>
```

**Keep `## Why` and `## For the reviewer` to one screen.** They're what the reviewer reads in full. Everything below them is there to look things up in. If the decisions don't fit on one screen, the PR is probably doing too much: split it (Step 1).

**Take the decisions from the docs, in the reviewer's words.** Use the spec's grill record, its ADRs and its decisions. Rank them by what's costliest to reverse, then by money or risk, then by behaviour users see, then by internal structure. This is `review-focus`'s guide applied to a PR. A decision the reviewer can't weigh without reading code doesn't belong in this list. Put the code location in the change map instead.

## Links

- **Link to the head commit, not the branch.** Merging deletes the branch, and a link to it breaks. A link to a commit keeps working. Get one with `gh browse <path> --commit=<head-sha> --no-browser`, and add `#<heading-anchor>` to point at a section.
- **Give the repo path too**, in backticks beside the link. An agent that has the repo checked out can open the file without a network call.
- **Refresh the description when the docs change**, or when the docs ↔ code check runs again. Edit only your own sections. Other tools append to the body: the CodeRabbit app adds a block that starts `<!-- This is an auto-generated comment`. So read the current body (`gh pr view <pr> --json body -q .body`), replace your sections, keep the rest, and write it back with `gh pr edit <pr> --body-file <file>`.

## The docs ↔ code check

**Who runs it.** A fresh subagent (`Agent`, `general-purpose`) that didn't write the change. Use the default model tier (`sonnet`). Use `opus` when the diff is large or spans many modules. It can run at the same time as the Step 3b verifier.

**What it's given.** The diff range (`origin/<base>...HEAD`) and the repo paths of the docs. Nothing else: no draft description, no summary of the change, no rationale from the chat. The check compares the code with what was written down. Telling it the author's intent in other words would hand it the very framing it exists to check.

**What it does.**

1. For each decision and behaviour the docs commit to within this PR's scope, it says one of three things, citing `file:line`:
   - implemented as written;
   - implemented differently (and how);
   - not implemented.
2. For each change in behaviour or structure in the diff, it says where the docs cover it (doc and section), or that they don't. Mechanical changes don't count: formatting, renames that follow a documented decision, and tests of documented behaviour.
3. It returns the verdict, `COVERED` or `GAPS`, with both lists and the commit it ran on.

It reads only and edits nothing.

**On `GAPS`.** Each item gets one of three outcomes before review is requested:

- **The code is right and the doc is out of date.** This is the common case: something was learned while building it. Update the doc in this PR, in the spec's "Changes during implementation" section or in the ADR, so the doc the reviewer approves matches the code that merges.
- **The doc is right.** Fix the code, then run Step 3 again, and Step 3b if behaviour changed.
- **A deliberate difference for now.** List it under "Differs from the docs", with the reason and a follow-up issue.

No gap goes unlisted. An unlisted gap is exactly where approving the docs stops meaning approving the code.

**The verdict covers the commit it ran on.** If a later fix from review or CI changes behaviour or structure, run the check again before the next push and before merging. Fixes to formatting, comments or tests only don't need it. Check with `git diff --stat <checked-sha>..HEAD`.
