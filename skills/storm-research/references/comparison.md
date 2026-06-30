# Three-way lineage: STORM paper · `deep-research` · the five-lens community skill

This doc records *why* `storm-research` (this skill) is built the way it is. It merges three sources.
Every STORM/Co-STORM claim below was verified 3-0 by the repo's `deep-research` harness
(25 claims checked, 0 killed) against primary sources, listed at the end.

## 1. Stanford STORM (the original method)

**STORM** = *Synthesis of Topic Outlines through Retrieval and Multi-perspective Question
Asking* (Shao et al., Stanford OVAL, NAACL 2024 — "Assisting in Writing Wikipedia-like Articles
From Scratch with LLMs"). It targets the **pre-writing** problem: how to research a topic from
scratch well enough to write a long, grounded, Wikipedia-style article.

**Two-stage pipeline:**

1. **Pre-writing (research):**
   - **Perspective discovery** — survey existing/related Wikipedia articles to mine *diverse
     perspectives*, then personify the LLM with each.
   - **Simulated conversation** — each perspective-carrying "writer" holds a multi-turn dialogue
     with a "topic expert" whose answers are **grounded in retrieved Internet sources** (a
     retrieval-augmented QA component). Follow-up questions are the engine: they raise reference
     count and information density.
   - **Outline curation** — consolidate the Q&A into a hierarchical outline.
2. **Writing** — generate the full-length article section by section from the outline + curated
   references, with citations, then polish.

**Why it beats naive baselines:** vs. an outline-driven RAG (oRAG) baseline, human Wikipedia
editors judged STORM articles **+25% absolute more organized** and **+10% broader in coverage**;
on outline metrics (GPT-3.5) heading soft recall **86.26% vs 73.59%** (naive RAG). Two insights:
*planning an outline first* improves coverage, and *multi-perspective grounded conversation*
increases reference density.

**Stated limitations (these shaped our guardrails):** articles lag humans on **neutrality** and
**verifiability**; low verifiability comes from **red-herring / overspeculation** (drawing
unverifiable connections), plus **bias and tone transfer** from sources.

**Co-STORM** (EMNLP 2024, "Into the Unknown Unknowns") adds **human-in-the-loop**: multiple LM
**experts + a moderator** hold a collaborative discourse while the user **observes and
occasionally steers**; agents ask questions on the user's behalf to surface *unknown unknowns*;
information is tracked in a **dynamic mind map**; output is a comprehensive report. Reported
preference: 70% over a search engine, 78% over a RAG chatbot (author-reported, small-N).

## 2. Built-in `deep-research` (the repo's current research skill)

A multi-agent **Workflow** optimized for **fact-checking**, not article-writing:

`Scope` (decompose into ~5 angles) → `Search` (5 parallel WebSearch agents) → `Fetch` (URL-dedup,
fetch ~15 sources, extract falsifiable claims) → **`Verify` (3 adversarial voters per claim,
refute-by-default; ≥2/3 refutes kill it)** → `Synthesize` (merge dupes, rank by confidence, cite).

**Strength:** rigorous, adversarial claim verification + source-quality hierarchy + confidence
ranking. **Gap vs STORM:** breadth-first and flat — no perspective modeling, no multi-turn
grounded interviews, no outline, no long-form article. It answers "what's true about X," not
"write the deep article on X."

## 3. The five-lens community skill (external prior art)

A community prose skill — "Stanford's Method Turns Claude Into a PhD Level Research Team"
(YouTube `Tj3018n5MVg`), closely tracking the `hadufer/claude-storm` plugin lineage. It was a
design input only; it is **not** vendored in this repo. It captures STORM's *spirit* with a
lighter, fixed structure:

5 **fixed lenses** (Practitioner, Academic, Skeptic, Economist, Historian), one brief each →
**contradiction map** → self-contained **HTML briefing** → **adversarial peer review +
primary-source citation verification**.

**Strengths we kept:** the prose-skill ergonomics, the contradiction map, confidence-ranked
findings, the **claim-safety guide** (assert/caveat/avoid), the frontier question, and hard
**no-fabrication** guardrails. **Where it diverges from real STORM:** fixed lenses instead of
*discovered* perspectives; a *single brief* per lens instead of *multi-turn grounded
conversations*; HTML briefing instead of an outline-driven long-form article.

## 4. What `storm-research` (this skill) takes from each

| Capability | STORM paper | `deep-research` | 5-lens skill | **this skill** |
|---|---|---|---|---|
| Perspective **discovery** (vs fixed) | ✅ | ❌ | ❌ (fixed 5) | ✅ discover, fixed-5 fallback |
| Multi-turn **grounded conversations** | ✅ | ❌ | ❌ (single brief) | ✅ (Phase 2) |
| **Outline-first** article generation | ✅ | ❌ | ❌ | ✅ (Phase 3–4) |
| **3-vote adversarial** verification | ❌ | ✅ | partial (peer review) | ✅ (Phase 5) |
| Confidence / source-quality ranking | ❌ | ✅ | ✅ | ✅ |
| Contradiction map + claim-safety guide | ❌ | ❌ | ✅ | ✅ (Phase 3, 7) |
| **Human steering** (Co-STORM) | ✅ (Co-STORM) | ❌ | ❌ | ✅ 2 gates |
| Long-form **article** output | ✅ | ❌ (report) | ❌ (HTML brief) | ✅ Markdown |
| **Implementation Brief** for a building AI | ❌ | ❌ | ❌ | ✅ (Phase 6 — net-new) |

The one thing no source had: an output **engineered for a downstream AI to build from** — a
structured Implementation Brief (requirements, decisions+rationale, schema, parameters,
interfaces, gotchas, build sequence) sitting under the article. That is the merged skill's reason
to exist.

## Primary sources (all verified 3-0)

- STORM paper: https://arxiv.org/abs/2402.14207 · https://arxiv.org/html/2402.14207v1
- Stanford project page: https://storm-project.stanford.edu/research/storm/
- Official repo (DSPy `knowledge-storm`): https://github.com/stanford-oval/storm
- Co-STORM paper: https://arxiv.org/abs/2408.15232 · https://aclanthology.org/2024.emnlp-main.554/
- LangGraph STORM tutorial: https://github.com/langchain-ai/langgraph/blob/main/docs/docs/tutorials/storm/storm.ipynb
- STORM-Research-Assistant (LangGraph): https://github.com/teddynote-lab/STORM-Research-Assistant
- claude-storm (Claude Code plugin): https://github.com/hadufer/claude-storm

**Caveats:** STORM's outline-quality margin is model-dependent (narrows at GPT-4); Co-STORM
preference figures are author-reported and small-N; practitioner reimplementations are moving
targets (teddynote-lab → braincrew-lab).
