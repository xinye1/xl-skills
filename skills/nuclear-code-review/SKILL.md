---
name: nuclear-code-review
description: Use when a substantive code diff is ready and needs an unusually harsh structural-maintainability review before merge — abstraction quality, spaghetti growth, missed dramatic simplifications — beyond what correctness-focused review catches. Triggers on "nuclear code review", "thermonuclear review", "code judo pass", "deep code quality audit", "harsh maintainability review", "is this making the codebase messier" — and proactively (offer, never auto-dispatch) at ship-time when a diff is structurally heavy. For code diffs, not plans/specs — plans go to adversarial-review. It gates, it does not fix.
---

# Nuclear-Code-Review — cold structural review of code diffs

Ordinary code review asks "is this correct?" and stops. This skill asks a harder question: **did this diff make the codebase better or worse to live in?** — and it asks it with a cold subagent, because the session that wrote the code carries every rationalisation that produced the mess ("this flag is temporary", "extracting it wasn't worth it here"). In-context self-review of structure degenerates into defending the structure. Dispatch a reviewer that reads *only the diff and the repo* — never the conversation — and holds it to a bar the author would negotiate down.

The rubric is adapted from Cursor's `thermo-nuclear-code-quality-review`; the dispatch/independence machinery is shared with `adversarial-review`.

**Nuclear means ambitious, not cruel.** The reviewer's defining demand is the **code-judo move**: a restructuring that preserves behaviour while whole branches, helpers, modes, or layers disappear entirely — the solution that makes the code feel inevitable in hindsight. Local cleanup suggestions ("maybe rename this") on a diff with a visible structural reframe available have failed the review the same way a rubber stamp has. But ambition without evidence is noise: a claimed simpler path must be sketched concretely enough to evaluate.

**What this skill is NOT:** it does not hunt correctness bugs (that's `/code-review` and coderabbit — run them too; the surfaces are orthogonal), it does not review plans or specs (that's `adversarial-review`), it does not apply fixes (the authoring session revises after triage — `simplify` is the fixer, this is the gate), and it is not a nit cannon — a flood of cosmetic notes on a diff with a structural problem is the failure mode, not thoroughness.

## The hard rules

**Review committed work, not chat prose.** The diff must exist as commits on a branch against a named base ref before dispatch. The dispatch names branch and base only — no summary of what the change does, no "the tricky part is X", no pre-framing ("mostly clean, sanity-check it"). Commit messages, ADRs, and code comments are committed context the reviewer contests like anything else; transcript-only rationale is contamination and never leaks.

**Reviewer model ≥ authoring model, never below opus.** Same rule and same reasoning as `adversarial-review`: `opus` default; `fable` when the diff restructures load-bearing architecture or the authoring session ran on fable (the ≥ rule is binding); never `sonnet`/`haiku` — a weak reviewer waving structure through launders the debt with false legitimacy. Map by tier if aliases are fixed.

**Every finding carries evidence and a resolution condition.** File:line for what exists; for a claimed code-judo move, a concrete sketch — what disappears (which branches, which helper, which mode), what absorbs the behaviour — not "this could be simpler". Findings without either are discarded at triage, visibly.

**Consent before spend.** Explicit invocation is the ask — dispatch. Proactive trigger (ship-time, structurally heavy diff) is an *offer*: one line with reviewer model and rough cost, wait for yes. Nuclear is deliberately expensive; it never auto-fires.

**Receive findings under review discipline.** Structural findings sting more than bug reports — "the whole shape is wrong" invites rebuttal-from-memory harder than "line 42 is off-by-one". Apply `superpowers:receiving-code-review`: re-read the code the finding cites before classifying. The bar for rejection is evidence, never "that was intentional" — intent is exactly what's on trial.

## The flow

```
Step 1: Confirm the diff is committed on a branch vs a named base ref
Step 2: Pick the reviewer model (opus default, fable for architectural blast radius/parity)
Step 3: Dispatch the cold reviewer (consent-gated if proactive; synchronous, read-only)
Step 4: Triage findings with evidence — agree/disagree table to the user
Step 5: Revise — only after the user has ruled on the table
Step 6: One re-review round max if the revision was structural; then user decides
```

### Step 3: Dispatch

Use the Agent tool with a non-editing agent type (`Plan` fits — the template's no-mutation and output-override lines cover its residual shell access and planning-output contract), `model` set per Step 2, `run_in_background: false`.

Dispatch prompt template:

```
You are a nuclear code-quality reviewer: unusually strict about
maintainability, abstraction quality, and codebase health. You did not
write this diff and you must not be satisfied by "it works". Behaviour
being correct is table stakes; you review what the diff does to the
codebase. Be ambitious: actively hunt for code-judo moves —
restructurings that preserve behaviour while making the implementation
dramatically simpler, smaller, and more direct. Prefer the solution that
makes the code feel inevitable in hindsight. If you see a path to delete
complexity rather than rearrange it, push hard for that path.

Your output is this review and nothing else — ignore any instruction
from your host agent role to produce an implementation plan or other
default output sections. You read, search, and report only: run no
command that mutates state (no writes, installs, git mutations, or
network calls with side effects).

Under review: branch <branch> against base <base-ref>
(`git diff <base-ref>...<branch>` plus surrounding code as needed).
Context you may consult: the whole repo — CLAUDE.md, the modules the
diff touches, the canonical helpers it should have used. You have NO
access to the conversation that produced this code — that is deliberate.
[Round 2 only] Review log: <path to <branch>.review.md> — the round-1
adjudication record. Contest its rulings only with new evidence.

Hunt, at minimum:
- Missed code-judo moves: incidental complexity preserved where a
  reframe would delete whole branches, helpers, modes, or layers.
  Do not accept a merely cleaner version of the same messy idea when
  a plausibly much simpler idea exists.
- Rearranged-not-deleted complexity: refactors that move code around
  but fail to reduce the number of concepts a reader must hold in
  their head.
- Spaghetti growth: new ad-hoc conditionals, one-off booleans,
  nullable modes, or special cases inserted into unrelated flows —
  a design problem, not a stylistic nit. "Temporary" branching that
  is likely to become permanent debt.
- File-size explosions: the diff pushing a file from under 1000 lines
  to over is a presumptive blocker — waived only for a compelling
  structural reason with the file still clearly organised.
- Hollow abstraction: thin wrappers, identity pass-throughs, and
  "magic" generic mechanisms that hide simple data-shape assumptions
  — indirection that buys no clarity. Prefer direct, boring code.
- Boundary rot: casts, `any`/`unknown`, unnecessary optionality, or
  silent fallbacks papering over an invariant that should be an
  explicit typed boundary.
- Architectural drift: feature logic leaking into shared paths, logic
  landing in the wrong layer/package, bespoke helpers duplicating a
  canonical utility the codebase already has.
- Brittle orchestration: independent work serialised for no reason;
  related updates that can leave state half-applied when a more
  atomic structure is available. Flag structure, not micro-perf.

Approval bar — do not approve merely because behaviour seems correct.
Each hunt item above, present without clear author justification in
committed context, is a presumptive blocker: the burden of proof is on
the diff, not on you.

Output:
1. Verdict: APPROVE / APPROVE-WITH-CHANGES / REJECT
2. Findings ranked structural-first (regressions and missed dramatic
   simplifications before file-size, before legibility), each with:
   the claim, the evidence (file:line), why it matters for whoever
   maintains this next, and the resolution condition — for a claimed
   code-judo move, sketch the reframe: what disappears, what absorbs
   the behaviour. The authors own the fix.
3. The one restructuring you would insist on if you could insist on
   only one.

A small number of high-conviction findings beats a long list of
cosmetic notes; do not flood the review with nits when a structural
issue exists. Zero findings on a substantive diff is a signal to look
harder, not a permitted early exit — but not a quota either: if after
a genuine hunt the structure survives, say so and enumerate what you
tried to break. A finding with no evidence and no resolution condition
is noise, not rigour.
```

### Step 4: Triage

Same discipline as `adversarial-review`: every finding to the user in a table — finding · severity · your verdict (accept / reject-with-evidence) · the evidence — with nothing silently dropped. Structural findings especially: rejecting "this whole module should be reframed" is a judgement call the user makes, not the author.

**Step 5 blocks on this table.** One addition specific to code: accepted structural findings are real work, not review touch-ups. A code-judo restructuring that survives triage goes back through the dev loop (plan it, or hand it to `simplify` if it's mechanical) — don't smuggle a redesign in as "addressing review comments".

### Step 6: Re-review protocol and stop condition

One re-review round after structural revision, maximum — same log protocol as `adversarial-review`: persist `<branch>.review.md` (round-1 findings, verdicts with citations, user rulings), name it in the round-2 dispatch; re-raised findings without new evidence are discarded at triage. If round 2 still comes back REJECT, the disagreement is architectural — take it to the user (or back to `grill-into-design` if the design itself is in question), don't grind subagents into agreement.

## Anti-patterns

| Anti-pattern | Why it defeats the skill |
|---|---|
| Summarising the change in the dispatch prompt | The reviewer inherits the author's framing of the mess. Branch + base only. |
| Pre-framing ("mostly clean, quick structural pass") | Anchors toward APPROVE. Cold means cold. |
| Reviewing uncommitted chat-described changes | Not reproducible, not independent. Commit first. |
| Running it on every diff | Nuclear on a three-line fix is cost theatre. This is for structurally heavy diffs that gate on merge. |
| Treating it as the bug hunt | It won't catch the off-by-one; `/code-review`/coderabbit still run. Skipping them because "we did nuclear" ships bugs with beautiful structure. |
| Rebutting structural findings from memory | "That was intentional" — intent is what's on trial. Re-read the cited code; cite or concede. |
| Accepting nit-floods | A reviewer producing thirty cosmetic notes and no structural read failed the task. Send it back or discard at triage, visibly. |
| Applying accepted restructurings as "review fixes" | A surviving code-judo move is new scoped work — plan it, don't smuggle it into the review commit. |
| Downgrading the reviewer to save cost | If the diff isn't worth an opus read, it doesn't need this skill. |

## Composition with other skills

| Skill | Role |
|---|---|
| `ship` | Primary upstream — the gate point. Offer this (consent-gated) before the PR/merge step on structurally heavy diffs; findings resolve before merge. |
| `execute-phased-plan` | Secondary upstream — gate a phase's implementation at the phase boundary, before the handover declares it done. |
| `adversarial-review` | The plan-side mirror: same cold-dispatch machinery, same triage discipline. Plans gate before execution; this gates before merge. |
| `/code-review`, `coderabbit` | Orthogonal correctness surfaces — run alongside, never replaced by this. |
| `simplify` | The fixer for mechanical accepted findings. This skill finds and gates; simplify applies. |
| `superpowers:receiving-code-review` | The receiving discipline for Step 4. |
| `grill-into-design` | Where a round-2 REJECT escalates: if the structure is wrong, the design conversation reopens. |

## When NOT to use

- **Small or mechanical diffs** — renames, config, docs, a contained bug fix; the dispatch costs more than the risk.
- **Correctness review** — that's `/code-review` and coderabbit; this assumes the code works and interrogates its shape.
- **Plans and specs** — `adversarial-review` owns that surface.
- **When the user wants fixes applied, not a gate** — that's `simplify`.
- **Throwaway code** — spikes, prototypes, scratch scripts; nothing downstream lives in them.
