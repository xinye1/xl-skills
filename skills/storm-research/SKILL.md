---
name: storm-research
description: Use for complex, reasoning-heavy research — especially research meant to drive product or development work (software, data pipelines, ML models, architecture, strategy, specs) — whenever a question needs multiple expert perspectives, source-grounded investigation, and fact-checking before anyone acts on the answer. Triggers on "research X", "investigate X", "STORM X", "deep dive on X", "compare options for X", "research X so we can build/decide Y". Append +eli5 for a human-facing plain-language layer. Not for quick fact-checks or one-off lookups — answer those directly.
argument-hint: "[topic] — optionally: what to build/decide from it · +eli5 for a human-facing version"
---

# STORM Research

## What this is

The repo's heavyweight research skill — a merge of three lineages into one prose skill:

- **Stanford STORM** (Shao et al., 2024 — *Assisting in Writing Wikipedia-like Articles From
  Scratch*) and its **Co-STORM** follow-up: discover *perspectives*, run multi-turn
  writer↔expert **conversations grounded in retrieval**, generate an **outline first**, then
  write the article section by section. Co-STORM adds **human steering**.
- The **`deep-research`** workflow (an earlier built-in research skill): **3-vote adversarial
  verification** (refute by default; ≥2/3 refutations kill a claim), a source-quality hierarchy,
  URL dedup, and confidence-ranked, cited findings.
- The **five-lens / contradiction-map approach** from community STORM skills (the "PhD research
  team" skill and the `hadufer/claude-storm` plugin) — used here as design influence, not vendored:
  contradiction mapping, confidence-ranked findings, a **claim-safety guide** (assert / caveat /
  avoid), a frontier question, and hard **no-fabrication** guardrails.

It adds one thing none of the three has: the deliverable is built to be **consumed by a
downstream AI agent to implement something** — not just read. Every run produces a long-form
article *and* a structured **Implementation Brief**, and can optionally mirror a **human-facing
layer**: an ELI5 plain-language version *plus* an interactive HTML page for human readers.

Run the full pipeline end to end. Honour the two gates. Do not shortcut a phase.

## When to use vs. a lightweight lookup

Pick by weight:

| Want | Use |
|---|---|
| A quick, fact-checked answer or one-off lookup | answer directly with WebSearch/WebFetch (or the platform's built-in research feature, if one exists) |
| Complex / reasoning-heavy research that will drive a build or a consequential decision | **this skill** |

If the topic is a simple factual lookup, this is overkill — say so and answer it the lightweight way.

## Portability

Self-contained. Uses only built-in tools: the `Agent` tool with `general-purpose` (or
`Explore`) subagents, `WebSearch`/`WebFetch` inside those agents, `Write`, and `AskUserQuestion`
for the gates. The optional human HTML page is rendered from `assets/human-page-template.html`
in this skill folder (inline CSS + vanilla JS, no external fonts/scripts/CDNs — opens offline).
No external scripts, APIs, or paid services.

---

## Phase 0 — Scope & consumer

1. Take the topic from `$ARGUMENTS`; if absent, ask for it in one line.
2. State your one-line interpretation of the topic and **proceed** — only ask a clarifying
   question if genuine ambiguity would change the research.
3. Pin down the **consumer of the output**, because it shapes the Implementation Brief (Phase 6):
   - *Who/what acts on this?* Default assumption: **a downstream AI agent that will implement a
     solution** (software / data pipeline / ML model / analysis / strategy).
   - *What is the intended build?* If the user stated it (e.g. "…then build a RAG service"),
     capture it. If not, infer the most likely build and say so in one line.
4. Derive a kebab-case `topic-slug` for filenames.
5. **Output options.** Decide whether to include the **human-facing layer** (in addition to the
   article + Implementation Brief). Read it from `$ARGUMENTS`: `+eli5` / "include an ELI5" /
   "explain like I'm 5" / "add a plain-language version" turn it **ON**; `-eli5` / "no ELI5" turn
   it **OFF**. Default **OFF**. When ON, the run produces *two* mirrored human artifacts — the
   **ELI5** Markdown section (Phase 7.1) **and** the interactive **HTML page** (Phase 7.2). The
   human layer is for people; the Implementation Brief is for AIs — independent concerns.
6. Tell the user the pipeline is running, name the two gates coming up (perspectives, outline),
   and state whether ELI5 is **on or off** so they can correct it before Gate 1.

## Phase 1 — Discover perspectives (STORM signature)  →  **GATE 1**

STORM's edge over a fixed panel is that perspectives are *discovered from the topic*, not
imposed. Do this inline (one or two scout searches are fine):

1. Survey how the topic is structured: skim 2-3 authoritative overviews / "table of contents"
   style sources and note the natural sub-areas, stakeholders, and schools of thought.
2. Derive **4-6 perspectives** tailored to the topic. A perspective = a role + what it most
   wants to know (its driving questions). Examples are topic-specific: for a database choice,
   perspectives might be *latency-sensitive app engineer*, *cost/FinOps owner*, *data-modelling
   purist*, *ops/on-call reliability*, *security/compliance*.
3. **Fallback panel.** If the topic resists natural perspectives, seed from a fixed five-lens
   panel — Practitioner, Academic, Skeptic, Economist, Historian — and adapt. Always keep at
   least one explicitly **skeptical / steelman-the-bear-case** perspective.

**GATE 1 (human checkpoint).** Present the perspective list (role + driving questions, one line
each) via `AskUserQuestion` or a tight prose list. Ask the user to approve, edit, add, or drop.
Do not proceed to conversations until they respond. This is the Co-STORM steering point that
most changes output quality.

## Phase 2 — Grounded writer↔expert conversations (STORM's engine)

This is the heart of STORM and the biggest upgrade over "one brief per lens." For **each
approved perspective**, spawn a `general-purpose` agent (all in one message, run concurrently).
Each agent runs a **multi-turn simulated conversation**, not a single answer:

> You are a curious **{PERSPECTIVE ROLE}** investigating: **{TOPIC}** ({TOPIC_FRAME}).
> Hold a multi-turn conversation with an expert to learn what your perspective most needs to
> know. Loop 3-5 rounds:
> 1. Ask a specific question driven by your perspective.
> 2. **Answer it ONLY from real retrieved sources** — use WebSearch then WebFetch the best
>    source; quote and cite (URL). If sources conflict, say so. **Never answer from memory; if
>    you can't find a source, say "unsupported" and move on.**
> 3. Ask a sharper follow-up that builds on what you just learned (dig into mechanism, numbers,
>    edge cases, failure modes — whatever your perspective cares about).
> Return: (a) 5-10 **grounded findings**, each a concrete checkable statement + a direct quote +
> source URL + your perspective's take on *why it matters for building something*; (b) the
> **2-3 open questions** you couldn't resolve; (c) any **source you'd flag as weak**. No
> invented studies, numbers, or URLs. Under 600 words.

When all return, post a 2-3 line chat note: where perspectives converge, the sharpest
disagreement. Keep the raw briefs out of chat. Pool all findings + sources for later phases.

## Phase 3 — Outline + contradiction map (STORM outline-first)  →  **GATE 2**

Work inline from the pooled findings (no agents):

1. **Contradiction map.** List where perspectives directly conflict (name the clashing claims,
   not just topics); rank evidence quality (peer-reviewed/official data > practitioner report >
   analogy/preprint); identify the single empirical **resolving question**; note the
   **universal agreement** (load-bearing, likely-true); name the **blind spot** no perspective
   covered (becomes the Frontier Question).
2. **Outline.** Draft a hierarchical article outline (sections → subsections). Fold the
   contradiction map in as explicit **"Tensions & open questions"** subsections rather than
   hiding disagreement. Ensure the outline has a path to the **Implementation Brief** (a section
   that turns the knowledge into buildable decisions).

**GATE 2 (human checkpoint).** Present the outline (+ a one-line note on the biggest tension).
Ask for approval/edits. Do not write the article until the user responds.

## Phase 4 — Write the article (section by section, grounded)

Write the long-form article in **Markdown** (canonical — it is the most AI-ingestible format),
to `storm-reports/{topic-slug}.md`:

- Write **section by section** following the approved outline; each claim that matters carries an
  inline citation `[n]` resolving to the References list.
- Lead with a decision-maker-grade **executive summary** (settled facts first, then contested
  interpretation).
- Surface tensions explicitly; do not launder disagreement into false consensus.
- Prose for humans, but keep structure clean (headings, tables, lists) so an AI can parse it.
- Do **not** finalize confidence scores yet — Phase 5 sets them.

## Phase 5 — Adversarial verification (from `deep-research`)

Before delivering, fact-check the draft the way `deep-research` does.

1. **Extract** the falsifiable, load-bearing claims from the draft (cap ~20-25; prioritize
   central claims and any surprising numbers).
2. **3-vote adversarial verification.** For each claim, spawn **3** `general-purpose` voters in
   parallel, each prompted to **try to refute**:
   > Be skeptical; try to REFUTE this claim. CLAIM: {claim + cited figure + source}. Check: is it
   > supported by the quote, or an overreach? WebSearch for credible contradicting evidence. Is
   > the source strong enough for the claim's strength (extraordinary claims need primary
   > sources)? Is it outdated, or marketing/press-release/cherry-picked? Return refuted
   > (true/false) + specific evidence + confidence + any counter-source. **Default to
   > refuted=true if uncertain.**

   A claim **survives** only with a quorum of real votes and **< 2 refutations**; ≥2/3 refutes
   kill it. (Group related citations into clusters and have a voter verify the cluster against
   its **primary** source — confirm title/authors/venue/year/figure/peer-review status.)
3. **Apply corrections.** Fix wrong figures/titles/dates; **demote** thin or contested claims
   into a "Contested signal — monitor, don't assert" callout; cut anything that can't be traced
   to a real source. Assign each surviving finding a **confidence 1-10** = evidence quality
   (peer-reviewed causal > official data > single survey > analogy > preprint), not vibes.
4. Fill a truthful **verification banner**: `N claims checked · X killed · Y corrected · Z demoted`.

## Phase 6 — Implementation Brief (the differentiator)

Append a structured, machine-actionable section the downstream agent can build from. This is
what makes the output *implementable*, not just readable. Title it **"Implementation Brief"** and
include, as applicable to the build identified in Phase 0:

- **Objective & scope** — what is to be built, in/out of scope, the consumer's role.
- **Requirements** — numbered, testable functional + non-functional requirements (each tagged
  `[must]` / `[should]` / `[could]`).
- **Key decisions & rationale** — the choices the research settles, each with the winning option,
  the rejected alternatives, and the evidence (cite finding/confidence). Mini-ADR form.
- **Constraints & assumptions** — limits, dependencies, and assumptions the build rests on.
- **Domain model / entities / schema** — entities, fields, relationships, or data shapes the
  research implies (as a table or a fenced code block — e.g. JSON/YAML/SQL — when concrete).
- **Algorithms / parameters / config** — methods, formulas, hyperparameters, thresholds, or
  config values with their sourced defaults.
- **Interfaces / integration points** — APIs, tools, libraries, protocols named in the research.
- **Gotchas & failure modes** — the traps surfaced by the practitioner/skeptic perspectives and
  the contradiction map; what breaks and how to detect it.
- **Open questions blocking implementation** — what must be resolved before/while building, with
  the resolving experiment where known.
- **Build sequence** — a suggested ordered task list a coding agent could pick up.

Make it concrete and parseable. Prefer tables and fenced code blocks over prose here. Mark any
item resting on a demoted/contested claim with `⚠ low-confidence`. **Do not invent specifics to
fill the template** — if the research doesn't determine a field, write `UNRESOLVED` and route it
to Open Questions. A confident-looking but fabricated schema is worse than an honest gap.

## Phase 7 — Deliver

1. **ELI5 (only if enabled in Phase 0).** Write a plain-language explainer for a non-expert human,
   derived **from the Phase 5 verified findings** (never the raw draft — so it stays accurate).
   ~150-300 words: no jargon, or define each term inline in one clause; one concrete everyday
   analogy; and cover *what it is · why it matters · the single biggest tension · the bottom line*.
   Label it as a simplification ("ELI5 — plain-language; see the article for the precise, cited
   version"). It only re-explains claims already verified above; it must introduce **no new
   claim, number, or nuance** of its own.
2. **Interactive HTML page (only if ELI5 enabled).** Clone `assets/human-page-template.html`,
   keep its CSS/JS verbatim, and fill the `{{PLACEHOLDERS}}` per the comment at the top of the
   file. It mirrors the human layer: leads with the ELI5, with a **Simple ⇄ Full** toggle that
   unfolds the verified depth, confidence meters on findings, collapsible tension cards, the
   assert/caveat/avoid guide, the frontier question, and the Implementation Brief in a
   collapsed copy-to-clipboard block. Write it to `storm-reports/{topic-slug}.html`. **The HTML
   must contain only content already in the verified report — no new claim, number, or styling
   gimmick that implies a finding the research didn't establish.** If ELI5 is OFF, skip this step.
3. Canonical artifact: `storm-reports/{topic-slug}.md` containing, in order: executive summary →
   **ELI5 (if enabled)** → article body (with tensions) → contradiction map → claim-safety guide
   (**assert / caveat / avoid**) → frontier question → **Implementation Brief** → References
   (every citation with a verification-status tag). Markdown stays canonical for AI consumption;
   the HTML page is the human companion.
4. If you produced the HTML page, offer to open it with the platform opener (Windows
   `start "" <path>` / PowerShell `Start-Process <path>`; macOS `open`; Linux `xdg-open`).
5. In chat, keep it tight: the `.md` path (and `.html` path if produced), the verification banner
   (`N checked · X killed · Y corrected · Z demoted`), the one universal finding, the frontier
   question, the claim-safety summary, a one-line pointer to the Implementation Brief, and whether
   the human layer (ELI5 + HTML) was included.

---

## Notes & guardrails

- **Real research only — zero fabrication.** Every finding, number, and citation traces to a
  real fetched source. If it can't be verified, demote or cut it; never paper over a gap. This
  applies doubly to the Implementation Brief: `UNRESOLVED` beats invented.
- **Perspectives are author-built; disclose it.** Cross-perspective agreement is a strong
  hypothesis, not field consensus. Don't present convergence as proof.
- **Verification is mandatory.** An article delivered without Phase 5 is not a STORM Research
  output. The banner must be truthful.
- **Counter STORM's known weakness.** The original STORM paper reports its articles lag humans on
  *neutrality* and *verifiability* — low verifiability traced to "red-herring fallacy /
  overspeculation" (unverifiable connections drawn between sources) and bias/tone bleeding in from
  sources. Phase 5's refute-by-default voting exists specifically to kill overreach and
  unsupported connections; the author-built-perspective disclosure and claim-safety guide exist to
  surface bias. Treat any "interesting connection" with no direct source as a red herring to cut.
- **Grounded conversations, not monologues.** The Phase 2 value comes from the *follow-up*
  questions answered from sources. A single answer per perspective is the failure mode to avoid.
- **Honour the gates.** Gates 1 and 2 exist because perspective choice and outline shape
  everything downstream. If the user pre-authorizes autonomous running ("no gates, just run it"),
  you may skip the pauses — but still print the perspectives and outline as you pass them.
- **Confidence = evidence quality, not confidence of tone.** Score on the source hierarchy.
- **Cost.** A run spawns roughly (perspectives) + (3 × verified-claims) + cluster-verifiers
  agents — commonly 20-40. That is expected for this skill. Don't fan wider than needed:
  4-6 perspectives, ~20-25 verified claims.
