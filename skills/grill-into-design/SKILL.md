---
name: grill-into-design
description: Use when starting a non-trivial design decision before code lands — feature design, architecture choices, spec'ing out a system. Triggers on "design a feature", "design X", "brainstorm X", "let's brainstorm", "spec out Y", "write a spec for Z", "plan a feature", "grill me on this", "stress-test this idea", "interrogate me on this plan", "let's figure out X together", "what should we build for Y" — or any signal that a non-trivial design decision is imminent and the user wants the tree walked rigorously before code. Prefer over `superpowers:brainstorming` when both could fire. The skill enforces a hard gate (no code, scaffolding, or implementation skills until spec approved) and terminates in a spec doc handing off to `superpowers:writing-plans`.
---

# Grill-Into-Design — interrogate then specify

This skill exists for one job: take an under-defined design idea and produce a spec that survives implementation. The mechanism is a structured grilling — you ask the user questions, but every question carries your own draft answer, so the user reviews instead of authors. The output is a real design document (not a chat transcript), and the handoff is to `superpowers:writing-plans` for the implementation plan.

This is the user's own hybrid of two upstream skills: `superpowers:brainstorming` (which has the right structure — hard gate, spec-doc terminus, visual companion) and Matt Pocock's `grill-with-docs` (which has the right tactics — recommended-answer pattern, branch enumeration, inline glossary, ADR-on-3-criteria). Pocock's "9 things people get wrong with /grill-*" post supplies the operational hygiene (token budget, prototype escape hatch, write spec before compacting).

**Who this skill is for:** the user when they're product-fluent on intent but want the design tree walked rigorously before any code lands. Especially right when the user is supervising AI-authored code across multiple languages and cannot afford the agent to drift on under-specified intent.

**What this skill is NOT:** it does not write code. It does not scaffold files. It does not "just stub it out to see if it works" — that's `[needs-prototype]` territory (see below) and only happens via an explicit escape hatch the user approves. The skill emits a spec and stops.

## The hard rules (read these before anything else)

**HARD-GATE.** Do not write code, scaffold a project, create implementation files, or invoke any implementation skill until you have presented a design AND the user has approved it. This applies to every project regardless of perceived simplicity. The design can be short (a few paragraphs for genuinely small work), but you MUST present it and get approval.

**One question at a time.** Never batch questions. If a topic needs more exploration, break it into multiple sequential questions. Multiple-choice with the recommended answer first is preferred when applicable; open-ended is fine when not.

**Every question carries your recommended answer.** Do not ask "what should we use for X?" — ask "I'd use X because of Y; agree, or push back?" The user reviews your draft instead of authoring from scratch. This is the single highest-leverage idea from Pocock.

**Cross-reference the code at every claim.** When you (or the user) make a statement about how the system behaves, check the actual code or spec. Cite `file:line`. If code disagrees with the stated behaviour, flag it before continuing.

**Glossary first, fuzzy language last.** Maintain a glossary file (see "Glossary discipline" below). When the user uses a term not in the glossary, propose a definition; user approves; it lands in the glossary inline. When the user uses a term ambiguously, challenge against the glossary: *"You used 'cohort' but the glossary defines only 'named cohort' (Spec 6a §10) — do you mean that, or something else?"*

## The flow

```
Step 1: Frame the scope + load context
Step 2: Open the glossary
Step 3: Offer the visual companion (if applicable)
Step 4: Grill — one question at a time, recommended answer each, branch-walked
Step 5: Token-budget check at ~120K — pause and write spec, handover if needed
Step 6: Propose 2-3 approaches with trade-offs (your recommendation first)
Step 7: Present the design in sections, approval gate per section
Step 8: Write spec doc
Step 9: Spec self-review (placeholder / contradiction / scope / ambiguity)
Step 10: Write ADRs if 3-criteria met
Step 11: User review of the written spec
Step 12: Handoff to superpowers:writing-plans
```

### Step 1: Frame the scope + load context

Before asking anything, do this:

- Read the user's request literally. If the scope describes multiple independent subsystems ("build a platform with chat, billing, analytics, ML serving"), flag this immediately — do not refine details of a project that needs decomposition first. Offer to decompose into sub-projects; brainstorm only the first one through the rest of this flow.
- Pull project context: recent commits (`git log --oneline -20`), any `CLAUDE.md` and project memory (`MEMORY.md`), top-level `README.md`, and the active specs directory (commonly `docs/superpowers/specs/` or `docs/specs/`).
- Identify the existing spec depth standard. If the project anchors on a specific spec as the reference (e.g. trading-platform-v2's "Spec 7a depth standard"), respect that depth. Don't bring brainstorming-skill brevity into a project that runs 80K-line specs; don't bring spec-7a verbosity into a hobby project.
- Identify the existing spec file location and naming convention (e.g. `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`). Adopt it. Don't invent a new location.

### Step 2: Open the glossary

The glossary file is **one of**: `docs/glossary.md`, `CONTEXT.md` at repo root, the project's `CLAUDE.md`, or a project-memory glossary entry. Check each in turn; pick whichever the project actually uses. If none exists, ask the user *one* question: *"I'd like to maintain a project glossary at `docs/glossary.md` so terms don't drift mid-grill. OK?"* — and if yes, create the empty file.

Read the glossary fully before grilling starts. Note terms that are likely to come up. As the grill proceeds, **update the glossary inline** whenever (a) a new term appears or (b) an existing term is being used in a way that doesn't match its definition.

Per Pocock: *"The glossary is a glossary and nothing else. Devoid of implementation details. Not a spec, not a scratch pad, not a decision log."* Decisions go to ADRs (Step 10); implementation goes to the spec doc (Step 8). The glossary's job is to make sure two sentences using the same word mean the same thing.

### Step 3: Offer the visual companion (if applicable)

If the topic is going to involve visual artefacts (UI mockups, layout comparisons, architecture diagrams), offer the visual companion *in its own message* — no other content combined:

> "Some of what we're working on might be easier to explain if I can show it to you in a web browser. I can put together mockups, diagrams, comparisons, and other visuals as we go. This feature is still new and can be token-intensive. Want to try it? (Requires opening a local URL)"

If they decline, proceed terminal-only. Even if they accept, decide per question whether to use it — a *conceptual* question about a UI topic stays in the terminal; a *visual* question goes to the browser.

If the topic is non-visual (backend design, infrastructure, data flow), skip this step entirely.

### Step 4: Grill — one question at a time, branch-walked, recommended answer

This is the heart of the skill. The grill walks down each branch of the design tree, resolving sub-decisions one by one. Each question carries your recommended answer.

**Branch enumeration.** Don't just ask the surface question ("which DB?"). Identify the sub-decisions that hang off it (which engine? managed vs self-hosted? schema isolation strategy? backup policy? read-replica topology?). Walk down each branch in dependency order. Ask sub-decisions only when they're actually contingent on the answer; if they're independent, defer them to their own branch.

**Question shape.**

Bad (open-ended, no recommended answer):

> What database should we use?

Better (recommended answer, but no branch enumeration):

> I'd use Postgres because of your existing JSONB columns and migration tooling. Agree, or push back?

Best (recommended answer + sub-decisions surfaced):

> I'd use Postgres 16 because of your existing JSONB columns, your sqlc tooling, and your Spec 2a 3-DB-role pattern. That implies: (a) managed (Cloud SQL) over self-hosted, (b) IAM-database-auth not password, (c) one instance per env not shared. Each of those is a sub-decision I'd default the same way unless you flag otherwise. Agree on Postgres? Push back on any of the three sub-decisions?

**Cross-reference at every claim.** "You said the kill-switch trips on a 3-state ladder — Spec 7e §G2 defines four states (Healthy/Warn/Stage/Halt). Did you mean four, or are you proposing a change?"

**Glossary challenge.** "You used 'feature' — the glossary defines that as 'Spec 4b §4.2 Feature = Charter §8 #5 PBI vertical-slice'. Do you mean that, or the data-science sense (input variable to a model)?"

**`[needs-prototype]` escape hatch.** When a question is genuinely high-fidelity — the right answer depends on seeing the UI, or running a small smoke test, or measuring something — mark it `[needs-prototype]`, move on, and resolve after a smoke implementation. Don't endlessly grind on a question that can't be answered without code.

**Stop condition.** The grill ends when shared understanding is reached, not when documentation is complete. Pocock's median is 40-100 questions per session; 16-50 is also common. If you find yourself proposing 20 sub-questions about a topic that the user clearly doesn't care about at this depth, you've over-grilled — stop and ship the spec.

### Step 5: Token-budget check at ~120K

At roughly 120K tokens of conversation context (you can estimate by line count if the harness doesn't expose token counts), pause and assess:

- Are we still adding signal, or going in circles?
- Are the major decisions made?
- Would the next 50 questions clarify the design or just refine surface detail?

If the major decisions are made and we're refining surface detail, **stop grilling and ship the spec now** (skip to Step 6-8). If there's substantial unresolved design space and the context is full, **handover to a fresh chat** via the `handover` skill — the next chat picks up from the glossary + ADRs + partial-spec state.

The cardinal sin per Pocock #6: *"Do not clear the context and start fresh just to write a PRD."* If you're going to compact context, **write the spec first**, then handover. The spec is the durable artefact; the chat transcript is not.

### Step 6: Propose 2-3 approaches with trade-offs

Once you understand what's being built, propose 2-3 approaches conversationally. **Lead with your recommended option and explain why.** Each option gets one paragraph of body and one short paragraph of trade-offs. Don't bury the recommendation under "well, it depends" — the user is paying for your judgement, not your hedging.

### Step 7: Present the design in sections, approval gate per section

Cover at minimum: architecture, components, data flow, error handling, testing, observability, deployment. Scale each section to its complexity — a few sentences for the straightforward parts, up to 200-300 words for nuanced ones.

Ask after each section whether it looks right so far. If the user pushes back on a section, revise that section before moving on; don't queue revisions.

### Step 8: Write the spec doc

Output: a single Markdown file at `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` (or whatever the project convention is — see Step 1). The file should be self-contained: a reader who has read the project's `CLAUDE.md` and the cited specs should be able to read this and understand the design without re-running the grill.

Match the project's existing spec depth and structure. If the project anchors on a reference spec (e.g. "Spec 7a depth standard"), follow it: top-level §0 background, numbered sections, Honest Caveats section at the end, cross-references to upstream specs.

Commit the spec to git with a short, descriptive message — but **do not push** unless the user explicitly asks. Commit is enough.

### Step 9: Spec self-review

Look at the spec with fresh eyes — read it top to bottom as if you'd never seen it. Check:

| Check | What to look for |
|---|---|
| Placeholders | Any "TBD", "TODO", incomplete sections, vague requirements |
| Internal consistency | Sections that contradict each other; architecture that doesn't match feature descriptions |
| Scope | Focused enough for one implementation plan, or does it need decomposition |
| Ambiguity | Any requirement readable two ways — pick one, make it explicit |
| Glossary terms | Every term used in the spec is in the glossary (or doesn't need to be) |

Fix any issues inline. No need to re-review — just fix and move on.

### Step 10: Write ADRs if 3-criteria met

For each significant decision made during the grill, check Pocock's 3 criteria:

1. **Hard to reverse** (more than 1 day of work to undo)
2. **Surprising without context** (someone reading the code would ask "why this way?")
3. **Result of a real trade-off** (you actually considered alternatives and picked one)

**If all three are true, write an ADR.** If any one is missing, skip — most decisions don't deserve an ADR.

ADR location: `docs/adr/NNNN-<short-title>.md` (where NNNN is the next 4-digit number). Format:

```markdown
# NNNN — <short title>

**Status:** Accepted
**Date:** YYYY-MM-DD

## Context

<the situation and constraints; why this came up>

## Decision

<what was decided, in one paragraph>

## Consequences

<what becomes easier; what becomes harder; what's locked in>

## Alternatives considered

- <alternative 1> — rejected because <reason>
- <alternative 2> — rejected because <reason>
```

Cap ADR body at ~200 words. ADRs are about *why*, not *how* — the how lives in the spec.

### Step 11: User review of the written spec

Stop and say:

> "Spec written and committed to `<path>`. Glossary updated (<N> new terms). <N> ADRs written. Please review and let me know if you want changes before we hand off to writing-plans."

Wait for response. If they request changes, make them and re-run Step 9. Only proceed when the user approves.

### Step 12: Handoff to `superpowers:writing-plans`

Invoke `superpowers:writing-plans` to produce the implementation plan. Do not invoke any other skill (not `to-prd`, not implementation skills, not frontend-design). The plan, not this skill, gates implementation.

## Recommended-answer pattern (in more detail)

The leverage from this pattern is that **the user reviews instead of authors**. Authoring a design from open prompts is hard; reviewing a draft is easy. This works because:

- You read the codebase and specs first, so your draft is grounded.
- The user knows the product context, so their review catches misreads.
- Yes/no/refine is a faster decision than "what do I want".

What this is *not*: leading the witness. You provide a recommendation *and* a one-line reason. The user can push back, propose a different option, or ask you to recommend differently. If your recommendation rate of "user accepts as-is" gets above ~80% across a grill session, you're probably under-challenging — make sure you're surfacing the actual sub-decisions, not just rubber-stamping consensus.

What this is also *not*: shotgunning multiple recommendations. One question, one recommendation, one ask.

## Glossary discipline (the CONTEXT.md / docs/glossary.md model)

The glossary file format:

```markdown
# Project Glossary

> **Discipline:** entries are 1-3 sentences, devoid of implementation detail. The glossary tells you what a term means, not how it works. Implementation lives in specs; rationale lives in ADRs; current state lives in code.

## A

- **<Term>** — <1-3 sentence definition>. [Spec X §Y if applicable]

## B

- **<Term>** — ...
```

Update rules:
- New term observed in a grill question → propose definition → user approves → add to glossary.
- Existing term used ambiguously → challenge against current definition → user clarifies → either reconcile usage or update the glossary.
- Decision details creeping in → strip them; the glossary is not a decision log.

Per Pocock: this is the single biggest preventive measure against agent-drift across long sessions and across chats. *"Agents are usually dropped into a project and asked to figure out the jargon as they go. So they use 20 words where 1 will do."*

## Anti-patterns

| Anti-pattern | Why it burns the user |
|---|---|
| Asking a question without your own recommended answer | The user has to author from blank — the slow, error-prone half of design. The recommended-answer pattern is the load-bearing tactic of this skill. |
| Batching three questions in one message | The user picks the easiest, the others get lost. One question per message, every time. |
| Skipping cross-reference | Stated behaviour drifts from coded behaviour silently. If you claim "kill-switch trips on 3 states" and Spec 7e says 4, that's a real bug — not a stylistic preference. |
| Treating the glossary as a scratch pad | Bloated glossary stops being load-bearing. Strip decisions and implementation details when they sneak in. |
| Writing ADRs for every decision | ADRs are scarce by design — apply the 3-criteria gate strictly. If everything is an ADR, nothing is. |
| Grinding on a `[needs-prototype]` question | If a question genuinely needs a smoke implementation, mark it and move on. Don't burn a session on a question that won't yield until code exists. |
| Writing the spec after compacting context | Spec quality degrades with context loss. Always: spec first, compact second. Pocock's #6 cardinal sin. |
| Endless grilling without ever spec-ing | Over-grilling. Pocock's #5: *"If you're just planning and planning without building, you're over-grilling."* Once the major decisions are made, ship the spec. |
| Outputting a chat-transcript summary instead of a spec doc | The chat is throwaway; the spec is durable. The user can't grep a chat. Write to the file. |
| Handing off to `to-prd` instead of `writing-plans` | Different output formats, different downstream consumers. This skill's terminus is `writing-plans`. |

## Composition with other skills

| Skill | Role |
|---|---|
| `superpowers:writing-plans` | The terminus. After the spec is approved, this skill invokes writing-plans to produce the implementation plan. |
| `superpowers:brainstorming` | The upstream this skill replaces for projects that adopt it. If both could fire, prefer this one — it has all of brainstorming's structure plus the grill tactics. |
| `superpowers:test-driven-development` | Downstream of writing-plans — the implementation skill enforces TDD on each task. This skill's spec should specify the audit surface so TDD knows what "done" means. |
| `handover` | Invoked at Step 5 when token budget is near ~120K and the design isn't complete. Pause, write what you have, hand off to a fresh chat. |
| `claude-md-improver` | Adjacent — if the grill surfaces a missing project convention, that's a signal to update `CLAUDE.md`, not to handle it in the spec. |
| `ship` | Downstream of the implementation plan. Not this skill's concern, but the spec → plan → ship chain is the full lifecycle. |

## When NOT to use this skill

- **Single-step tasks** — "rename this variable", "fix this typo", "bump this dependency". Just do the work; no grilling needed.
- **Bug fixes with a known root cause** — go to `superpowers:systematic-debugging` instead.
- **Pure exploration** — "what could we do about X" with no commitment to building anything. A 2-3 sentence answer with a tradeoff is enough; don't run a 40-question grill on a hypothetical.
- **The user explicitly says they want a fast answer** — respect that. Confirm: "fast answer, or proper grill?" If fast, give the fast answer and skip this skill.
- **The user has explicitly asked for `superpowers:brainstorming`** — honour their explicit choice.
- **Greenfield design that's already specced** — if the project already has its design specs (e.g. trading-platform-v2's 16-spec corpus), and the work is just executing them, go straight to `superpowers:writing-plans` instead of grilling on a fait accompli.

## Quick invocation phrases

These trigger this skill — recognise and invoke without asking for clarification (but still do Step 1 to load context):

- "design a feature"
- "design something"
- "design X" (where X is a feature/module/component)
- "brainstorm X"
- "let's brainstorm"
- "spec out Y"
- "write a spec for Z"
- "plan a feature"
- "plan out X"
- "grill me on this"
- "grill me about X"
- "stress-test this idea"
- "stress-test this design"
- "interrogate me on this plan"
- "let's figure out X together"
- "what should we build for Y"
- "I want to design X"
- "help me design X"
- (implicit) user describes a non-trivial design problem and asks "where should I start" or "how should I approach this"

## Lineage

Hybrid of `superpowers:brainstorming` (hard-gate, section-by-section presentation, spec-doc terminus, `writing-plans` handoff) and Matt Pocock's grill skills (recommended-answer pattern, branch-walking, inline glossary, ADR-on-3-criteria gate, 120K-token budget, `[needs-prototype]` escape hatch). Neither alone fits high-stakes greenfield design where the reviewer is product-fluent but can't audit the diff line by line.
