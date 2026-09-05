---
name: elii
description: Use when the user says "ELII" (explain like I'm an intern), "ELI5", "explain like I'm...", "what does X stand for?", "what do you mean by Y?", "what does it mean ... to me?", "clarify these concepts", "I don't have <domain> knowledge", "digestible information to make a decision", or "this is too complicated for me to read" — or when they ask what a term/acronym means that a previous reply used without defining. ALSO INVOKE PROACTIVELY, BEFORE ENDING ANY CHAT-LEVEL TURN THAT ASKS THE USER FOR A DECISION, SIGN-OFF, APPROVAL, "YOUR CALL" OR GO/NO-GO: write the ask as a plain-language decision brief (what needs deciding · what you need to know · options with what happens · my lean), never as project shorthand or item codes (R3-5, K6b, #580). A long spec/plan/ADR presented for sign-off goes to `review-focus` instead. Same for "why did this happen" narratives, recovery summaries, and ops side-effects on the user's machine. A manual "elii" after one of these means the reply failed and costs a full extra turn.
---

# ELII — explain like I'm an intern, calibrated to this user

The user is a **data scientist with a product and design mindset**: fluent in ML, statistics, experimentation, and product reasoning; *not* fluent in programming-language internals, infra, networking, or finance-domain jargon. "ELII" is their standing request to translate into that register — an intelligent colleague from a different specialty, not a beginner.

## Calibration — what needs unpacking and what doesn't

- **Assume fluent:** ML concepts (features, overfitting, ensembles, cross-validation), statistics (correlation, significance, distributions), product/UX reasoning, experiment design.
- **Assume NOT fluent:** infra/ops (containers, migrations, reverse proxies, systemd), networking (tailnets, ports, SSH keys), software-engineering internals (enums, transactions, race conditions), mobile platform mechanics (adb, app signing, permissions), finance mechanics (NAV, PIT data, order lifecycles), and any project-local shorthand ("VR", "box", "pin", "L2", "lift", "re-band", "clause b", "guard A").
- Over-explaining the fluent column is as bad as under-explaining the other — it reads condescending and wastes their time.

## The shape of an ELII answer

For each concept (batch several as a mini-glossary when the user lists them):

1. **Plain one-liner** — what it is, no jargon, acronym expanded.
2. **In our system** — where it shows up concretely *here*, with real values from the current work ("NAV = net asset value: cash + what our open positions are worth; the £20k cap is checked against this").
3. **Why it matters now** — the decision or risk it connects to. This is usually why they asked.
4. **Analogy to their world** when it genuinely maps (a DB index ≈ a pandas index; a migration ≈ a versioned schema-change script; a blocking gate vs a log line ≈ a pipeline that refuses to run until the protocol is amended vs a manual-intervention note the analyst is hoped to read) — skip forced analogies.

Rules that hold across all four parts: expand every acronym on first use; introduce **zero new undefined jargon** inside the explanation; prefer one concrete worked example over abstract description; answer the *decision behind the question*, not just the literal term — "what does the budget even mean?" is really "should I keep paying this cost?".

## Proactive register — don't wait to be asked

When producing anything the user must read and act on (recommendations, specs to approve, session summaries, runbooks), write it in this register from the start. A follow-up like "what's VR?" or "you say 'box' a lot" means a previous reply failed the register — fix the term inline *and* keep it defined for the rest of the session. If a doc must use technical terms, add a compact inline glossary rather than footnotes. When the user asks for a doc "in both rigorous and ELII languages", deliver both layers, clearly separated — the rigorous layer is not a substitute for the plain one.

### The decision brief — mandatory shape for any ask that needs the user's call

Mined from a month of sessions (2026-08-04 → 09-04): of 11 manual ELII triggers, **6 came immediately after a turn that ended by asking for a decision**, and every one of them was followed by an instant compressed answer ("1 go, 2 yes, 3 yes" · "Let's go with Option A" · "1 correct it, 2 pessimistic now"). The information was always sufficient; the *form* was the blocker. The user's own formula for what they needed: *"what you need my decision on, what info I have to do that, what are the options, what's your lean?"*

So, before ending a turn with a question for the user, restate the ask as a **numbered** brief, one block per decision (max ~5 — more means the document needs a `review-focus` reviewer's guide instead):

1. **What needs deciding** — one plain sentence. Name the thing, not its label: "whether the paper account's per-order cap goes from $3.5k to $6.5k", not "R3-4".
2. **What you need to know** — the two or three facts that make the choice, with the terms unpacked in place. Real values from the current work. If a term needs more than a clause, it goes in a mini-glossary above the brief.
3. **Options, and what happens under each** — 2–3 options, each as *consequence for the user*, not mechanism: "(i) block: the nightly stops until you sign a rule change; the refused attempt is still recorded" not "(i) raise on the third override". A small table works well.
4. **My lean and why** — one recommendation, the reason, and the one caveat that is genuinely the user's judgement. Include **when it bites** (today / next Tuesday / only once live nights count) and the **cost of choosing wrong** (reversible in a sentence / a re-run / irreversible).

Number the blocks so the reply "1 yes, 2 (ii), 3 not sure" works. If a decision sits inside the user's fluency (an ML/stats trade-off), give the rigorous version — they decide those themselves.

### Tells that a reply is about to bounce (each one is a documented past bounce)

- Items referred to by **code without restating what they are**: "task C", "K6b", "R3-5", "decision-7", "#580", "caveat 11". The user reads across many sessions and does not hold the spec in working memory.
- **Project shorthand undefined**: box, pin, L2/un-gate/lift, soak, re-band, clause b, guard A, sha, the ladder, the fuse.
- **Options framed by mechanism** ("register `native_top25_guarded` as the deployed interim and keep the stateless top-25 as the ablation control") rather than by what the user will observe.
- **"Why it happened" told as a defect ledger** (PR numbers, shas, hashes) instead of by cause class — wipe-caused vs pre-existing vs newly introduced, and whether it can recur.
- **An ops side-effect on the user's own machine** stated in daemon terms ("next sway reload puts it back under exec_always") without "what this means for you / what, if anything, you need to do".
- **Nested option trees** ((a)/(b)/(c) with (i)/(ii) inside) ending in a question. Flatten into the numbered brief.

## Why this is worth the extra paragraph

A manual "elii" is a whole new turn at the session's current context size. Measured on the Sep 2026 sessions: a bare "elii" at ~390k context cost ~$0.9, and the "what do you need my decision on" bounce at ~750k context cost ~$3.7 — plus the wall-clock and the user's attention. The proactive brief is a few hundred output tokens on the turn that already holds the context. Cost scales with context (see the 1M-context quadratic-burn gotcha), so late-session decision asks are exactly where the brief matters most.

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| Dictionary definition detached from the project | They asked because it appeared in *our* context; generic definitions don't unblock the decision. |
| Baby-talk simplification of ML/stats content | Wrong audience — they're an expert there; it hides the substance they can evaluate. |
| Explaining with more undefined jargon | Recursion, not explanation. |
| Wall of text per term | One tight paragraph per concept; concision is a standing preference. |
| Answering the term but not the underlying decision | "What's a family?" was really "why are we giving up on the others?" — address both. |
| A decision ask by item code, assuming the user holds the whole spec in mind | Guaranteed bounce: the user has to ask what K6b *is* before they can rule on it. |
| Options without a lean | Pushes the whole decision back; the lean plus its cost-of-wrong is what makes a one-word answer safe. |

## When NOT to use

- The user asks a deep technical question *inside* their fluency (ML methodology, stats) — engage at full expert level.
- They want the rigorous version alongside — provide both layers (rigorous + ELII), clearly separated, as they've requested for knowledge write-ups.
- A long artifact (spec, plan, ADR) presented for sign-off — that is `review-focus` territory (a ranked reviewer's guide); the decision brief here is the chat-level equivalent for a handful of decisions.
