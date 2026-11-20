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

1. **Read the description and the docs it links**, at the PR's head: `gh pr view <pr> --json body,headRefOid,baseRefName,files`. The teammate's commits may not be in your clone yet, so fetch them first: `git fetch origin <baseRefName> pull/<pr>/head`. Then read each linked doc at that commit (`git show <headRefOid>:<path>`). Keep the `gh pr view` output: step 4 compares with it. Treat the description as the author's claims, not as facts.
2. **Check the premise.**
   - **The reviewer sections or a doc are missing.** Then the premise doesn't hold for this PR. Tell the user plainly that approving the description won't approve the code. Offer to request changes that ask the author for the missing docs, or a code review (`/code-review`) instead. Don't offer approval on the description alone.
   - **A trivial PR** (`Docs: none needed (<reason>)`) has no reviewer sections by design. Check that the diff fits the reference's trivial tier. If it does, the premise doesn't apply: the diff is small enough to read, so give a short guide to it. If it doesn't, treat it as a missing doc.
   - **Otherwise, run the docs ↔ code check yourself**, whatever verdict the description carries. That verdict says what was true when the author ran it, and the PR may have moved since. Use the brief in `ship`'s reference: a fresh subagent given only the diff range and the doc paths, never the description. Give it the PR's commits (fetched in step 1) as explicit commits, `$(git rev-parse origin/<baseRefName>)...<headRefOid>`, and tell it to read each doc at that commit (`git show <headRefOid>:<path>`), not from the working tree. When the description is the doc, save its `## Why` and `## For the reviewer` sections to a file and give the checker that file as the doc. Only `COVERED`, with or without listed differences, lets approving the description approve the code. If your verdict differs from the author's, say so in the guide.
3. **Give the guide**, in this skill's four parts, numbered:
   - the decisions to weigh, from the docs, each with your view;
   - assumptions;
   - what's safe to skim;
   - deep-dive pointers.

   Add a fifth part, **where the code and the docs part ways**, from the check: differences the description lists, and any it doesn't. An unlisted difference is the one place the user has to read code. Point them at the file and line.
4. **The user decides.** Draft the review the way they rule. Approval means the decisions are agreed and the differences accepted. A change request names the decision or difference it's about. Post it only when they say so. Right before posting an approval, fetch and read the PR again (as in step 1). Then run the check once more on what you fetched, if step 2 ran one; for a trivial PR, read the diff again and confirm it is still trivial. If the head, base or description changed, or the result differs from the one the guide showed, update the guide and ask again. A change request needs none of this. The user ruled on the description they read, so an edited one needs their eyes again even when the check still passes. Then post for the commit you just checked, so a push that lands meanwhile isn't approved unseen. `gh pr review` can't name a commit, so use the API, with `<event>` `APPROVE` or `REQUEST_CHANGES` to match their ruling:

   ```bash
   gh api repos/{owner}/{repo}/pulls/<pr>/reviews -f commit_id=<checked-sha> -f event=<event> -F body=@<file>
   ```

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
| Taking a PR description's "the code follows the docs" on trust | It's the author's claim about the PR as it was when they ran the check. The PR may have moved since. Run the check yourself, and again right before posting. |

## When NOT to use

- Short artifacts (≤ ~2 screens) — the user can just read them.
- Documents for a peer session or agent, not the user — those need completeness, not a filter (`cross-session-brief`).
