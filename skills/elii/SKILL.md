---
name: elii
description: Use when the user says "ELII" (explain like I'm an intern), "ELI5", "explain like I'm...", "what does X stand for?", "what do you mean by Y?", "clarify these concepts", "I don't have <domain> knowledge", or "this is too complicated for me to read" — or when they ask what a term/acronym means that a previous reply used without defining. Also use proactively to set the register of any explanation, doc, or summary written for the user in domains outside their fluency (software engineering, infra, networking, finance/trading mechanics, mobile).
---

# ELII — explain like I'm an intern, calibrated to this user

The user is a **data scientist with a product and design mindset**: fluent in ML, statistics, experimentation, and product reasoning; *not* fluent in programming-language internals, infra, networking, or finance-domain jargon. "ELII" is their standing request to translate into that register — an intelligent colleague from a different specialty, not a beginner.

## Calibration — what needs unpacking and what doesn't

- **Assume fluent:** ML concepts (features, overfitting, ensembles, cross-validation), statistics (correlation, significance, distributions), product/UX reasoning, experiment design.
- **Assume NOT fluent:** infra/ops (containers, migrations, reverse proxies, systemd), networking (tailnets, ports, SSH keys), software-engineering internals (enums, transactions, race conditions), mobile platform mechanics (adb, app signing, permissions), finance mechanics (NAV, PIT data, order lifecycles), and any project-local shorthand ("VR", "box", "pin").
- Over-explaining the fluent column is as bad as under-explaining the other — it reads condescending and wastes their time.

## The shape of an ELII answer

For each concept (batch several as a mini-glossary when the user lists them):

1. **Plain one-liner** — what it is, no jargon, acronym expanded.
2. **In our system** — where it shows up concretely *here*, with real values from the current work ("NAV = net asset value: cash + what our open positions are worth; the £20k cap is checked against this").
3. **Why it matters now** — the decision or risk it connects to. This is usually why they asked.
4. **Analogy to their world** when it genuinely maps (a DB index ≈ a pandas index; a migration ≈ a versioned schema-change script) — skip forced analogies.

Rules that hold across all four parts: expand every acronym on first use; introduce **zero new undefined jargon** inside the explanation; prefer one concrete worked example over abstract description; answer the *decision behind the question*, not just the literal term — "what does the budget even mean?" is really "should I keep paying this cost?".

## Proactive register — don't wait to be asked

When producing anything the user must read and act on (recommendations, specs to approve, session summaries, runbooks), write it in this register from the start. A follow-up like "what's VR?" or "you say 'box' a lot" means a previous reply failed the register — fix the term inline *and* keep it defined for the rest of the session. If a doc must use technical terms, add a compact inline glossary rather than footnotes.

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| Dictionary definition detached from the project | They asked because it appeared in *our* context; generic definitions don't unblock the decision. |
| Baby-talk simplification of ML/stats content | Wrong audience — they're an expert there; it hides the substance they can evaluate. |
| Explaining with more undefined jargon | Recursion, not explanation. |
| Wall of text per term | One tight paragraph per concept; concision is a standing preference. |
| Answering the term but not the underlying decision | "What's a family?" was really "why are we giving up on the others?" — address both. |

## When NOT to use

- The user asks a deep technical question *inside* their fluency (ML methodology, stats) — engage at full expert level.
- They want the rigorous version alongside — provide both layers (rigorous + ELII), clearly separated, as they've requested for knowledge write-ups.
