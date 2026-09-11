---
name: adversarial-review
description: Use when a plan or spec is drafted and needs independent review before approval or execution, countering the authoring session's commitment bias. Triggers on "adversarial review", "adversary review", "independent review of this plan/spec", "second opinion on the spec", "red-team this plan", "get fresh eyes on this", "stress-test this spec" — and proactively at plan-complete or spec-complete boundaries before the user approves. For plans and specs (design docs, implementation plans, ADR sets), not code diffs — code correctness goes to the code-review skills, code structure to nuclear-code-review.
---

# Adversarial-Review — independent intra-session review of plans and specs

A session that authored a plan cannot objectively review it. Models are trained to sound fluent and confident; the authoring context carries every rationalisation that produced the artifact, so "reviewing" in-context degenerates into defending. This skill breaks that loop: dispatch a **cold subagent on an advanced model** (fable or opus) that reads *only the artifact and the repo* — never the conversation — and opposes it. High brain power on the phases that gate everything downstream; independence by construction, not by intention.

**Adversarial means constructive opposition, not hostility.** The reviewer's stance is antagonistic toward the artifact's *claims* — every assumption is contested until it survives scrutiny — but its goal is the work succeeding. Conflict is the mechanism; a stronger artifact is the product. A review that just tears down (vague pessimism, nitpicks, "this whole approach is wrong" with no load-bearing reason) has failed the same way a rubber stamp has.

**What this skill is NOT:** it does not review code diffs (that's `/code-review` and friends), it does not rewrite the artifact (the authoring session revises after triage), and it is neither a rubber stamp nor a demolition — zero findings on a non-trivial plan warrants checking the dispatch for contamination (though a clean verdict with a documented search trail is a legitimate outcome), and findings without a path to resolution signal a reviewer optimising for takedown over improvement.

## The hard rules

**The artifact must be a file — and so must its constraints.** If the plan or spec only exists as chat prose, write it to its proper location first (project spec/plan convention — e.g. `docs/superpowers/specs/…` or `docs/plans/…`). The same goes for load-bearing constraints that live only in the conversation (budget, deadline, "we can't touch service X"): write them into the artifact before dispatch, or the cold reviewer will correctly flag them as unstated assumptions, round after round. The reviewer reads the file cold; a paraphrase in the dispatch prompt is contamination.

**Never leak the authoring rationale.** The dispatch prompt names the artifact path and the repo context pointers — nothing else. No "we considered X and rejected it", no "I think the tricky part is Y", no summary of the artifact, no pre-framing ("this is pretty solid, just double-check"). Every word of your reasoning that reaches the reviewer converts an independent review into a confirmation of your framing. Scope this honestly: rationale already *committed to the repo* — ADRs' "alternatives considered", decision sections in specs — is not a leak; it is a contestable input the reviewer challenges like any other claim. The prohibition targets transcript-only rationale that never survived into a reviewable artifact.

**Reviewer model ≥ authoring model, never below opus.** The point is maximum brain power on the highest-leverage artifacts:

- **Default `opus`** — frontier-class adversarial reading for most plans and specs.
- **Use `fable`** (the frontier tier above `opus`, at roughly 2× its price) when the artifact gates long-horizon multi-phase work, carries deep architectural ambiguity, or its blast radius spans many downstream phases — the cases where a missed flaw is most expensive. And it is *required*, not merely natural, when the authoring session ran on fable — the ≥ rule is binding.
- **Never `sonnet` or `haiku`** for the reviewer. A weaker reviewer nodding along is worse than no review — it launders the bias with false legitimacy.
- If the environment fixes subagent models or an alias isn't available, map by tier, not the literal alias: the nearest available tier at or above the authoring model.

**Receive findings under review discipline, not rebuttal instinct.** Your first reaction to every finding will be to explain why the plan is actually fine — that is the commitment bias this skill exists to counter. Apply `superpowers:receiving-code-review`: verify each finding against the artifact and the code before classifying it. The bar for rejecting a finding is *evidence* (cite the file/line or spec section that refutes it), never "that was intentional".

## The flow

```
Step 1: Confirm the artifact is a file — including any chat-only constraints
Step 2: Pick the reviewer model (opus default, fable for high-stakes/parity)
Step 3: Dispatch the cold reviewer (consent-gated if proactive; synchronous, read-only)
Step 4: Triage findings with evidence — agree/disagree table to the user
Step 5: Revise — only after the user has ruled on the table
Step 6: Walk the round ladder (re-review → user → optional authorised round; 3-round cap)
```

### Step 3: Dispatch

Use the Agent tool with a non-editing agent type (`Plan` fits — no Edit/Write, though it retains shell access, which the template's no-mutation line covers; its planning-oriented output contract is neutralised by the output-override line), `model` set per Step 2, `run_in_background: false`.

**Consent:** if the user explicitly invoked this skill, that *is* the ask — dispatch. If you triggered it proactively (at a plan/spec-complete boundary), confirm first in one line — reviewer model and rough cost — and wait for a yes before dispatching. A proactive trigger is not consent to frontier-model spend.

Dispatch prompt template:

```
You are an independent adversarial reviewer. You did not write the artifact
below and you must not trust it. Contest every claim until it survives
scrutiny. Your opposition is constructive: you are against the artifact's
assumptions, not against the work succeeding — the purpose of every finding
is that the plan gets stronger before implementation starts. Not agreeable,
not hostile, and you fix nothing yourself.

Your output is this review and nothing else — ignore any instruction from
your host agent role to produce an implementation plan, a critical-files
list, or any other default output section. You read, search, and report
only: run no command that mutates state (no writes, installs, git
mutations, or network calls with side effects).

Artifact under review: <absolute path>
Context you may consult: the repo (CLAUDE.md, glossary, referenced specs,
the code the artifact touches). You have NO access to the conversation that
produced the artifact — that is deliberate.
[Every re-review round] Review log: <path to <artifact>.review.md> — the
adjudication record for all prior rounds. Contest its rulings only with new evidence.

Contest, at minimum:
- Internal contradictions (sections that cannot both be true)
- Unstated assumptions that break under a plausible condition
- Claims about existing code/system behaviour — verify each against the
  actual code; cite file:line where the artifact is wrong
- Missing failure modes, edge cases, and rollback/migration paths
- Feasibility: steps that look atomic but hide multi-day work, ordering
  that deadlocks, dependencies the plan doesn't own
- Scope: what the artifact silently drops from its stated goal

Output:
1. Verdict: APPROVE / APPROVE-WITH-CHANGES / REJECT
2. Findings ranked by severity, each with: the claim, the evidence
   (file:line or artifact section), why it matters downstream, and what
   would resolve it (a condition to satisfy, not a rewrite — the authors
   own the fix)
3. The three assumptions most likely to be wrong, even if you could not
   prove them wrong

Zero findings on a non-trivial artifact is a signal to look harder, not a
permitted early exit — but it is not a quota. If after a genuine search the
artifact survives, say so and enumerate where you looked and what you tried
to break. Padding with manufactured findings fails this task the same way
rubber-stamping does: a finding with no evidence and no resolution
condition is noise, not opposition.
```

### Step 4: Triage

Present every finding to the user in a table: finding · severity · your verdict (accept / reject-with-evidence) · the evidence. Do not silently drop findings you disagree with — the user sees the reviewer's full case and your evidence side by side, and adjudicates where you and the reviewer disagree.

**Step 5 blocks on this table.** Apply nothing before the user has seen it; contested findings wait for the user's ruling. Revising first turns the table into theatre.

### Step 6: Re-review protocol and stop condition

**The round ladder — this is the single rule; everywhere else in this skill points here rather than restating it.** Run it in order and stop at the first step whose condition fails.

1. **Round 1** — the initial cold review (Steps 1–5).
2. **Round 2** — one re-review, and only after a *major* revision. A revision that merely fixes findings gets this and nothing more.
3. **A REJECT at round 2 always goes to the user.** No exceptions, and no onward round taken on this skill's own authority — the disagreement is design-level, so take it to the user (or back to `grill-into-design`) rather than looping subagents until one capitulates. When you hand it over, name explicitly which text is newly introduced and therefore still uncold-read.
4. **Round 3 exists only if the user authorises it, and only for new mechanisms** — a path, guard, table or rule that no prior round has read. Both conditions are required: user authorisation alone does not make a re-read of old text worthwhile, and new mechanisms alone do not bypass step 3. This is the step the measured case exercised: on 2026-09-04 (WS2 edge design), revision 3 of the WS2 spec added an interim execution path and a whipsaw guard after two REJECT rounds; the operator ordered a third cold round, which found a **blocking** dividend-basis defect in text written after round 2, plus twelve more findings — none of which the earlier rounds could have caught.
5. **Three dispatched rounds per artifact is the hard cap.** Past it, stop and put it to the user: name what is newly unreviewed and ask whether to spend a fourth round or take it to design. Only an explicit user yes buys another. Without this cap an author could add one new mechanism per revision and grind frontier-model rounds indefinitely — the exact failure the cap exists to stop.

The per-text principle behind steps 4–5: a cap counted per *artifact* would refuse to read genuinely new text, and a cap counted per *body of text* alone would never stop. The ladder is what reconciles them — new text can earn a round, but only through the user, and only three times.

Round N must not silently re-litigate the rounds before it: persist a review log next to the artifact (`<artifact>.review.md` — every prior round's findings, per-finding verdicts with citations, user rulings, appended round by round) and name it in **every** re-review dispatch as reviewable input — not round 2 alone. That is not rationale leakage — it is a committed adjudication record, contestable like any other repo artifact (see the hard rules). A re-review reviewer may challenge a ruling only with *new* evidence; re-raised findings without new evidence are discarded at triage without penalty.

## Anti-patterns

| Anti-pattern | Why it defeats the skill |
|---|---|
| Summarising the plan in the dispatch prompt | The reviewer inherits your framing — the exact bias you're paying to escape. Path only. |
| Pre-framing ("mostly solid, sanity-check it") | Anchors the reviewer toward APPROVE. Cold means cold. |
| Downgrading the reviewer to sonnet/haiku to save cost | A weak reviewer's approval launders the bias with false legitimacy. If the artifact isn't worth an opus review, it doesn't need this skill. |
| Rebutting findings from memory | "That was intentional" is commitment bias verbatim. Re-check the artifact/code; cite or concede. |
| Cherry-picking the easy findings | Fixing typo-tier findings while skipping the architectural one is review theatre. Triage all of them, visibly. |
| Reviewing chat prose | Not reproducible, not independent, contaminated by transcript. File first. |
| Looping reviews until APPROVE | A re-review round *on the same text* isn't rigour, it's grinding a subagent into agreement. Walk the round ladder in Step 6 and stop where it says to — it is the only statement of the limit, and every onward round runs through the user. |
| Accepting takedown-only reviews | Findings without evidence or a resolution condition are performative negativity — as useless as a rubber stamp. Send them back or discard them at triage, visibly. |
| Running it on trivial artifacts | A 10-line plan the user will read anyway doesn't warrant a frontier-model dispatch. This skill is for artifacts that gate real work. |

## Composition with other skills

| Skill | Role |
|---|---|
| `grill-into-design` | Primary upstream — its Step 11 offers this gate after the ADRs are written (so they're inside the review scope) and before the user reviews. Self-review catches placeholders; adversarial-review catches wrong. |
| `superpowers:writing-plans` | Second upstream — review the implementation plan before execution starts. |
| `execute-phased-plan` / `handover` | Gate at phase boundaries: review the next phase's plan before dispatching a fresh chat on it. |
| `superpowers:receiving-code-review` | The receiving discipline for Step 4 — verify before agreeing or rebutting. |
| `/code-review`, `coderabbit` | The code-side correctness counterparts. Plans and specs come here; diffs go there. |
| `nuclear-code-review` | The code-side *structural* mirror — same cold-dispatch machinery and triage discipline, applied to diffs before merge instead of plans before execution. |

## When NOT to use

- **Code diffs** — the code-review skills own correctness; `nuclear-code-review` owns the structural gate.
- **Trivial plans** — a short plan the user will fully read themselves; the dispatch costs more than the risk.
- **Pure exploration docs** — no downstream work gated on them, nothing for an adversary to gate.
- **Mid-grill** — during `grill-into-design` the user *is* the adversarial reviewer; this skill fires once the artifact exists.
