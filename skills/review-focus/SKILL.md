---
name: review-focus
description: Use when handing the user a long document to approve — a spec, plan, ADR, research report, or review findings — and whenever they say "which bits should I focus on?", "point out the high value review points", "so I don't have to read this end to end", "the plan is too complicated for me to read", or "ELI5 the summary". Trigger proactively: any artifact over ~2 screens presented for sign-off should arrive with a reviewer's guide attached, unprompted. The user is the product owner signing off on judgement calls, not a line-editor of the document.
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

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| Handing over a 500-line spec with "please review" | The user either rubber-stamps it or stalls; either way the judgement calls go unexamined. |
| A guide that summarises the document | Summaries still make the user do the filtering. The guide *is* the filter: decisions, assumptions, skip-map. |
| Review points without a recommendation | Pushes the whole decision back to the user; the recommendation + risk is what makes a 1-word answer safe. |
| Ranking by document order | Puts naming bikesheds ahead of the irreversible money decision. |
| Implementation-level review points | The user explicitly doesn't review at that level; those belong to code review / subagent review. |
| Unnumbered points | Breaks the user's "1 yes, 2 agree" reply pattern. |

## When NOT to use

- Short artifacts (≤ ~2 screens) — the user can just read them.
- Documents for a peer session or agent, not the user — those need completeness, not a filter (`cross-session-brief`).
