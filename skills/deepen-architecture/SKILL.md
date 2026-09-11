---
name: deepen-architecture
description: Use when the question is "what should we restructure?" rather than "is this diff okay?" — surveying an existing codebase for architectural friction and turning it into a ranked set of deepening candidates. Triggers on "improve the architecture", "where's the architectural debt", "what should we refactor", "this codebase is hard to navigate/test", "find the shallow modules", "architecture review", "deepen X", "why does changing one thing mean touching six files". Also use proactively when a phase retro keeps surfacing the same module as friction. Whole-codebase and proactive; a specific ready diff goes to nuclear-code-review instead. It surveys and proposes — it does not refactor.
---

# Deepen-Architecture — survey for depth, report visually, then grill the pick

Most architecture conversations fail because they start at the wrong altitude: someone proposes a refactor, and the discussion is instantly about that refactor rather than about whether it's the one worth doing. This skill inverts that. It surveys the codebase for **friction**, converts the friction into **deepening opportunities** — restructurings that turn shallow modules into deep ones — and presents them side by side as a visual report so the choice is made on comparison, not on whoever spoke first.

The bar for a candidate is the **deletion test**: imagine the module gone. If complexity vanishes, it was a pass-through and deleting it is the win. If complexity reappears smeared across N callers, it was earning its keep and deepening it is the win. A candidate that survives neither reading isn't a candidate.

The vocabulary is load-bearing and non-negotiable — **module, interface, implementation, depth, deep, shallow, seam, adapter, leverage, locality** — defined in [references/deep-modules.md](references/deep-modules.md). Read it before the survey. Drifting into "component", "service", "API", "boundary", "layer", or "cleaner code" is how an architecture review turns into a vibes review: those words let two people agree on a sentence while picturing different changes.

**What this skill is NOT:** it does not refactor (it emits a ranked report and stops), it does not review a diff (`nuclear-code-review` owns that — this runs when there *is* no diff yet), it does not design the new interface (the pick hands off to `grill-into-design`), and it is not a lint sweep — a list of forty small smells is the failure mode, not thoroughness.

## The hard rules

**Scope before you scan.** Deepening pays off only where change actually lands, so survey where the codebase is hot, not where it's biggest. If the user named a direction — a module, a subsystem, a pain point — take it and skip inference. Otherwise walk back a meaningful stretch of `git log --oneline --name-only` and let the files that keep reappearing pull attention first. Scattered history with no hot spot is itself a finding — widen the net and say so. **A whole-repo scan with no scoping pass is the expensive failure mode**: it costs the most and returns candidates in code nobody touches.

**Read the repo's own vocabulary first.** The domain glossary (`docs/glossary.md`, `CONTEXT.md`, or whatever the repo uses — same discovery as `grill-into-design`'s glossary discipline) gives the good seams their real names. ADRs in `docs/adr/` record decisions this survey must not re-litigate. A candidate named "the FooBarHandler refactor" when the glossary says "Order intake" has already lost the reader.

**Subagents observe; the orchestrator judges.** Explorers report friction with `file:line` evidence and nothing else — no proposed solutions, no candidate names. Synthesis, the deletion test, and the vocabulary live with the orchestrator. Letting each explorer propose its own fix produces three private vocabularies and a report that reads like three reports.

**No interfaces at candidate stage.** The report says what hurts, what would change in plain English, and what the shape becomes — never a proposed type signature. Designing the interface before the user has picked a candidate spends the expensive thinking on candidates that get discarded, and anchors the grilling that follows.

**Consent before the second spend.** The survey is one cost; the grilling loop is another. Stop at the report and ask which candidate to explore. Never roll straight from "here are six candidates" into designing one.

## The flow

```
Step 1: Scope      — user's direction, else git-log hot spots; read glossary + ADRs
Step 2: Explore    — parallel read-only subagents report friction with evidence
Step 3: Synthesise — cluster friction into candidates; apply the deletion test; rank
Step 4: Report     — publish the Artifact, hand over the URL, ask which one
Step 5: Grill      — the pick goes to grill-into-design; glossary/ADR updates land inline
```

### Step 2: Explore

Dispatch `Explore` agents (read-only) — one per scoped area, **three at most**, in parallel. Default model is fine; this step gathers evidence, it doesn't exercise judgement. Give each one an area and this hunt list:

```
Report architectural friction in <area> as observations only. Do NOT
propose solutions, refactors, or names for them — that is not your job
and it will be discarded.

Hunt for:
- Concepts you cannot understand without bouncing between many small
  files — where does following one behaviour take the most hops?
- Modules whose interface is nearly as complex as their implementation
  (everything a caller must know: signature, invariants, ordering,
  error modes, required config — not just the type).
- Pure functions extracted for testability where the real bugs live in
  how they're called, not in what they compute.
- Tightly-coupled modules leaking across their seams — one module
  reaching into another's internals or reconstructing its invariants.
- Code that is untested, or testable only by reaching past its
  interface into internals.

For each observation: file:line evidence, what you were trying to
follow when you hit it, and how many files/hops it took. No prose
essays — evidence and hop-counts.
```

### Step 3: Synthesise

Cluster the raw friction into candidates. For each, before it earns a card:

1. **Apply the deletion test** and record the answer. "Concentrates complexity" is the signal you want; "just moves it" kills the candidate.
2. **Classify its dependencies** — in-process / local-substitutable / remote-but-owned / true-external — because that determines how the deepened module gets tested and whether a port is justified. See [references/deep-modules.md](references/deep-modules.md).
3. **Check seam discipline** — one adapter is a hypothetical seam, two is a real one. Don't propose a port that only ever has one implementation.
4. **Assign strength** — `Strong` / `Worth exploring` / `Speculative`. Be honest; a report where everything is Strong ranks nothing.
5. **Check ADRs.** If a candidate contradicts one, surface it *only* when the friction is real enough to warrant reopening the decision, and mark it plainly in the card. Don't enumerate every refactor an ADR forbids.

Four to six candidates is a report. Twelve is a lint sweep — cut to the ones that would change how the next month of work feels.

### Step 4: Report

Publish as an **Artifact** (private by default, shareable when the user chooses, persists past the session). Load the `artifact-design` skill first, and `artifact-diagramming` for the before/after visuals. Format specifics — card anatomy, diagram patterns, the vocabulary discipline in prose — are in [references/report-format.md](references/report-format.md).

The diagrams carry the weight. **If a diagram needs a paragraph to be understood, redraw the diagram.**

End with a **Top recommendation** section: which one you'd tackle first and why, in one sentence. Then hand over the URL and ask which candidate to explore. Stop there.

### Step 5: Grill the pick

The chosen candidate goes to `grill-into-design` — the interface, what sits behind the seam, what tests survive, what the migration costs. That skill owns the conversation and terminates in a spec; this one is done.

Two side effects land inline as decisions crystallise, not as a cleanup pass afterwards:

- **Deepened module named for a concept the glossary doesn't have?** Add the term to the repo's glossary then and there (create it lazily if absent).
- **User rejects a candidate for a load-bearing reason?** Offer an ADR — *"want me to record this so future surveys don't re-suggest it?"* Only when the reason would actually stop a future explorer; skip the ephemeral ("not now") and the self-evident.

## Anti-patterns

| Anti-pattern | Why it defeats the skill |
|---|---|
| Scanning the whole repo with no scoping pass | Maximum cost, and candidates in code nobody touches. Hot spots first. |
| Explorers proposing solutions | Three private vocabularies, three framings, one incoherent report. They observe; you judge. |
| Skipping the deletion test | Without it every abstraction looks improvable and nothing is ranked. It's the filter, not a formality. |
| Proposing a port with one adapter | That's indirection wearing a seam's clothes. Two adapters or no port. |
| Drifting to "component"/"service"/"cleaner code" | Ambiguous nouns let everyone agree while picturing different changes. Use the glossary terms exactly. |
| Naming candidates after classes (`FooBarHandler`) | The reader thinks in domain terms. Use the repo's glossary names. |
| Designing the interface inside the report | Spends the expensive thinking on candidates about to be discarded, and anchors the grill. |
| Everything badged `Strong` | A ranking where nothing loses is not a ranking. |
| Rolling from report straight into designing | Two separate spends. The user picks first. |
| Re-litigating a settled ADR | Surface it only when friction justifies reopening, and say which ADR and why. |
| Running this on a diff | Wrong tool — `nuclear-code-review` reviews diffs; this surveys standing code. |

## Composition with other skills

| Skill | Role |
|---|---|
| `grill-into-design` | The terminus. The picked candidate becomes the design conversation, then a spec. |
| `nuclear-code-review` | The diff-side mirror. Same structural instincts, opposite trigger: that one gates a change at merge, this one finds changes worth making. |
| `superpowers:writing-plans` → `execute-phased-plan` | Downstream of the spec — a deepening large enough to phase gets planned and paced like any other work. |
| `summarise-session` | The natural upstream signal: when retro after retro names the same module as friction, that's this skill's cue. |
| `review-focus` | Pair with it when handing over the report — the candidate ranking *is* a set of judgement calls for the user to sign off. |
| `artifact-design` / `artifact-diagramming` | Required reading before Step 4. |
| `simplify` | For friction that turns out to be local mess rather than architecture — cheaper, applies fixes directly. |

## When NOT to use

- **A specific diff is on the table** — `nuclear-code-review`, every time.
- **The refactor is already decided** — go to `grill-into-design` (or straight to a plan). Surveying a fait accompli wastes the survey.
- **Small or young codebases** — under a few thousand lines there's no navigation cost to recover; the survey costs more than the finding.
- **A known local mess** — one gnarly file, no structural question: `simplify`.
- **Mid-incident** — architecture surveys are not debugging. `superpowers:systematic-debugging` first, and the friction it exposes becomes input to a survey later.
- **Prototypes and spikes** — shallow is correct when nothing downstream lives there.

## Lineage

Adapted from Matt Pocock's [`improve-codebase-architecture`](https://github.com/mattpocock/skills/tree/main/skills/engineering/improve-codebase-architecture), whose deep-module vocabulary and process (scope by hot spots → visual candidate report → grilling loop) this skill keeps. Pocock's version depends on a separate `codebase-design` skill for the vocabulary and renders to a temp-dir HTML file over Tailwind/Mermaid CDNs; here the vocabulary is folded into `references/` so the skill stands alone, the report is an Artifact (self-contained, no CDN, shareable and persistent), the grilling handoff goes to `grill-into-design`, and the glossary/ADR hooks discover the repo's own conventions rather than assuming `CONTEXT.md`. The underlying ideas are Ousterhout's deep modules (*A Philosophy of Software Design*) and Feathers' seams (*Working Effectively with Legacy Code*).
