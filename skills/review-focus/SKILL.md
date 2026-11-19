---
name: review-focus
description: Use when handing the user a long document to approve — a spec, plan, ADR, research report, or review findings — and whenever they say "which bits should I focus on?", "point out the high value review points", "so I don't have to read this end to end", "the plan is too complicated for me to read", or "ELI5 the summary of a long doc under review". Also when the user is reviewing a teammate's pull request — "review PR #N", "help me review this PR", "what do I need to look at in this PR", "can I approve this?" — where the guide comes from the PR's description and the docs it links. Trigger proactively — any artifact over ~2 screens presented for sign-off should arrive with a reviewer's guide attached, unprompted. The user is the product owner signing off on judgement calls, not a line-editor of the document.
---

# Review focus — a reviewer's guide for the product owner

Long documents get approved, not read. The user's sign-off is only meaningful on the parts that carry *their* judgement — product behaviour, money, risk, scope, irreversibility. The reviewer's guide extracts exactly those, in their language, and licenses them to skip the rest.

## The guide (attach to the document, or produce on request)

1. **Decisions that need your judgement** — ranked, max ~7. For each: the question in one line, **my recommendation and why in one or two more**, and what happens if we choose wrong (cost of reversal). Rank by: irreversible > touches money/risk > user-facing behaviour > internal structure. These are the items where the user's answer would change the document.
2. **Assumptions I made on your behalf** — defaults chosen without asking (thresholds, naming, provider tiers, scope cuts). One line each; the user veto-scans them.
3. **Safe to skim, and why** — name the sections that are mechanical consequence of decisions already made (boilerplate, standard patterns, test plans) so skipping is a decision, not a guilt.
4. **Deep-dive pointers** — section references (§ or heading names) so any point can be expanded on demand.

## Register rules

- **Product language, not implementation language.** "Rejected-by-broker orders get their own label so you can tell them from ones you declined" — not enum names. Implementation detail appears only when it *is* the judgement call.
- ELII discipline applies (see `elii`): expand acronyms, no undefined jargon, concrete values from the actual document.
- Terse. The guide fits on one screen; if it can't, that's a smell that the *document* needs restructuring or the decisions need pre-filtering, not that the guide should grow.

## Interaction pattern

Expect answers in the user's compressed style ("1 yes, 2 agree, 3 ELI5") — number every point so this works. When a point gets a challenge instead of a yes, resolve it in place (this is a `grill-into-design`-style exchange in miniature), update the document, and say what changed. When all points are resolved, state plainly that the document is approved-as-amended and what happens next.

## A teammate's pull request

The user is the second developer, approving a PR they won't read line by line. The team's premise is that approving the docs approves the PR, as long as the code follows the docs. `ship` writes descriptions for this reader (`ship`'s `references/pr-description.md`). Your job is to check that the premise holds for this PR, then hand over the guide.

1. **Read the description and the docs it links**, at the PR's head: `gh pr view <pr> --json body,headRefOid,baseRefName,files`. Then read each linked doc at that commit. Note what the guide will cover: the `headRefOid`, the `baseRefName`, and a hash of the `## Why` and `## For the reviewer` sections (the same `sha256sum` the reference uses), for every PR. Treat the description as the author's claims, not as facts.
2. **Check the premise.** Three things can break it:
   - **The reviewer sections are missing**, or a doc the description depends on isn't in the repo.
   - **The docs ↔ code verdict doesn't cover the head**: commits that change behaviour or structure, or a decision in a doc the verdict covered, landed after the commit it names (`git diff --stat <checked-sha>..<head>`, then read the changes to any doc in that list). When the description is the doc, also hash its `## Why` and `## For the reviewer` sections the way the reference says, and compare with the hash the verdict records. A different hash with a changed decision means the verdict is stale.
   - **The verdict is missing.**

   If it's missing or stale, run the check yourself. Use the brief in `ship`'s reference: a fresh subagent given only the diff range and the doc paths, never the description. Check the PR's commits, not the branch you happen to be on. Run `git fetch origin <base> pull/<pr>/head`, then give the checker `<base-sha>...<headRefOid>` as explicit commits, and tell it to read each doc at that commit (`git show <headRefOid>:<path>`), not from the working tree. When the description is the doc, save its `## Why` and `## For the reviewer` sections to a file and give the checker that file as the doc, as the reference says.
3. **Give the guide**, in this skill's four parts, numbered:
   - the decisions to weigh, from the docs, each with your view;
   - assumptions;
   - what's safe to skim;
   - deep-dive pointers.

   Add a fifth part, **where the code and the docs part ways**, from the check: differences the description lists, and any it doesn't. An unlisted difference is the one place the user has to read code. Point them at the file and line.
4. **The user decides.** Draft the review the way they rule. Approval means the decisions are agreed and the differences accepted. A change request names the decision or difference it's about. Post it only when they say so. First check that the PR hasn't moved since the guide: the same `headRefOid`, the same `baseRefName` (a retargeted PR is a different diff on the same head), and the same hash of the reviewer sections, for every PR (an author can edit them without a commit). If any changed, update the check and the guide and ask again. Then post with the one command that matches their ruling: `gh pr review <pr> --approve --body-file <file>` to approve, or `gh pr review <pr> --request-changes --body-file <file>` to ask for changes.

The guide stays within the PR's own decisions. Correctness bugs and structure are other reviews (`/code-review`, `nuclear-code-review`). If the user wants one, offer it. Don't fold it in.

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| Handing over a 500-line spec with "please review" | The user either rubber-stamps it or stalls; either way the judgement calls go unexamined. |
| A guide that summarises the document | Summaries still make the user do the filtering. The guide *is* the filter: decisions, assumptions, skip-map. |
| Review points without a recommendation | Pushes the whole decision back to the user; the recommendation + risk is what makes a 1-word answer safe. |
| Ranking by document order | Puts naming bikesheds ahead of the irreversible money decision. |
| Implementation-level review points | The user explicitly doesn't review at that level; those belong to code review / subagent review. |
| Unnumbered points | Breaks the user's "1 yes, 2 agree" reply pattern. |
| Taking a PR description's "the code follows the docs" on trust | It's the author's claim about the commit it ran on. A stale or missing check means approving the docs no longer approves the code. |

## When NOT to use

- Short artifacts (≤ ~2 screens) — the user can just read them.
- Documents for a peer session or agent, not the user — those need completeness, not a filter (`cross-session-brief`).
