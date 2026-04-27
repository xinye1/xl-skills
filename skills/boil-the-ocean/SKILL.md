---
name: boil-the-ocean
description: Implementation completeness discipline — do the whole thing, not just the plan to build it. Use whenever doing non-trivial implementation work (features, bug fixes, refactors, config changes) to push past "good enough" toward "holy shit, that's done." Triggers on starting any non-trivial implementation; before claiming a task is complete; when tempted to "table this for later" / present a workaround / leave a dangling thread / skip tests / skip docs when the permanent solve is within reach. Use even if the user hasn't explicitly asked — implementation tasks default to this discipline. Completeness is bounded by the asked-for scope, not unbounded polish. Broader than `superpowers:test-driven-development` (covers tests *plus* docs and loose ends) and stronger than `superpowers:verification-before-completion` (drives implementation toward complete, not just verifies what's already there).
---

# Boil the ocean — implementation completeness

This skill is a behavioral standard, not a workflow. Its job is to make one specific failure mode louder than it would otherwise be: **stopping short on implementation work when the permanent solve was close**. The name comes from Gary Tan, who inverted the usual idiom — classically, "boiling the ocean" means trying to do too much. In the AI era the marginal cost of completeness is near zero, and the failure mode flipped: stopping early, presenting workarounds, and leaving dangling threads now costs more in aggregate than just doing the whole thing.

## The standard

The bar for finished work is **"holy shit, that's done"** — a reaction, not a checkbox. "Politely satisfied" is failure. The reaction the user has when they see the work matters more than any internal sense of completion you arrived at.

Three concrete things this means in practice:

1. **The asked-for thing is fully built and verified, not described and gestured at.** "A plan to do X" is not "X." The deliverable is the working artifact.
2. **The supporting work the asked-for thing needs is done with it.** If the feature needs tests to actually be a feature, the tests are part of the deliverable. If the bug fix needs a regression test to actually be a fix, the test is part of the fix. If the new public function needs a docstring or README entry to be usable, the docs are part of the function.
3. **Loose ends inside the work are tied off, not noted as TODOs.** If implementing X surfaces a related Y that you can finish in a few more minutes, finish it. The "five more minutes" rule isn't pedantic — it's that the *next* time anyone sees that loose end, the cheap context for fixing it is gone, so the dangling thread either ships indefinitely or costs 10× to revisit.

## What this is NOT — the scope boundary

This skill is not a license to scope-creep. The system prompt's rules — "don't add features, refactor, or introduce abstractions beyond what the task requires", "don't add error handling for scenarios that can't happen" — still hold. They are not in conflict with this skill; they describe a different boundary.

| Boundary | Who enforces it | What it says |
|---|---|---|
| **Scope** | The system prompt's "don't add features beyond the task" rule | Don't invade the next-door scope. |
| **Completeness within scope** | This skill | Everything inside the asked-for scope is fully done. |

Concretely: the user asked you to add a function that parses user-supplied dates. **In scope and required by this skill:** the function exists, has type hints, has a unit test for the normal path and at least one obviously-broken input, and the README's API table mentions it if the project documents its API there. **Out of scope and forbidden by the system prompt:** rewriting the surrounding date library, adding a CLI for dates, retrofitting other parsers, generalising to other types.

Boiling the ocean means doing the *whole* of the in-scope work — not invading the next-door scope. If you're unsure whether a piece of work is in or out of scope, ask the user one short question rather than deciding silently in either direction. Silent under-doing and silent over-doing are both expensive.

## The five anti-patterns this skill kills

These are the specific micro-decisions where work gets left half-done. The pattern is the same in each: a small in-the-moment thought that *feels* reasonable, but consistently leaves the user holding the bag. Notice the thought; reverse it.

| Tempting thought | Why it's wrong | What to do instead |
|---|---|---|
| "I'll add a TODO for the test" | The TODO sits unaddressed indefinitely. Five minutes to write the test now is cheaper than the time it costs anyone — including future-you — to rebuild context for it later. | Write the test now. |
| "I'll work around it for now and we can do the proper fix later" | The workaround usually ships. The proper fix usually doesn't. If the root cause is identified and the fix is bounded, "later" almost never arrives. | If the root cause is identified and the fix is bounded, do the root-cause fix. If the root cause is genuinely outside this task's scope, name it explicitly to the user and let them decide — don't quietly install a workaround. |
| "I'll leave a comment explaining the limitation" | A comment is not a fix. Documenting intentional behaviour is legitimate; commenting on a defect to defer it is an excuse with markdown. | Fix the underlying behaviour. Reserve comments for invariants and surprising-but-correct decisions, not deferred bugs. |
| "Type-check passed, that's probably enough" | Type-check passing is necessary, not sufficient. It says the code compiles, not that it does the thing. | Run the tests. If there's no test for the affected path, write the smallest one that would have caught a real failure, then run it. |
| "Let me just stop here and check in" | Often a covert way of handing the unfinished part back to the user. The genuine "real decision needed" case is the exception, not the default. | Don't stop unless there's a decision only the user can make. If the next step is mechanical and the goal is unambiguous, do it. |

## Search before building

Before writing new code, look for the thing you're about to write:

- `grep` / `glob` for the function name, the concept, the import you'd need.
- Read adjacent files in the same module — you may be about to write a parallel of something already there.
- For library or framework usage, fetch current docs (the project's pinned version) rather than relying on memory of the API. The Microsoft Learn / Context7 / firecrawl docs MCPs are there for this; use them.

A 30-second search is far cheaper than writing, debugging, and maintaining a duplicate of something the codebase already had. This is the cheapest "boil the ocean" move available — it costs almost nothing and the upside is large.

## The done-check

Before claiming a task is done, walk through these five questions. If any answer is "no" or "not sure", the task is not done.

1. **Does the asked-for thing work end-to-end?** Not "the code compiles" — actually run the path the user will exercise. For UI work, open it in a browser and click through it. For a CLI, run the command. For a library function, call it from a script.
2. **Is it covered by a test that would catch it breaking?** For features: the normal path and at least one obviously-broken input. For bug fixes: a regression test that fails without your change and passes with it.
3. **Are the docs that the project actually uses updated?** Public API reference, README entry, type signatures, docstrings — whichever the project actually consults. Don't write docs the project has no convention for; do update the docs the project does.
4. **Are the loose ends inside this diff resolved, or explicitly out of scope?** Half-finished implementations, dead branches, unused imports, TODOs left by *this* change — all gone, or named to the user as out of scope with a reason.
5. **Did you verify, or are you assuming?** "Tests pass" requires running them. "Lint clean" requires running lint. Don't claim what you didn't verify. This is `superpowers:verification-before-completion`, quoted here because it is a hard prerequisite for the standard above.

If the answer to all five is yes, the work is at "holy shit, that's done." If not, you know what's left — go finish it.

## When the user has authority over this skill

Two situations where the user's instruction beats this skill's default:

1. **The user explicitly asked for less.** "Just sketch the function signature, don't implement it" / "Patch it, we'll do the proper fix next sprint" / "Skip the tests for this prototype." Honour the explicit ask. The skill is the default; the user can override it.
2. **A project-level rule conflicts.** A `CLAUDE.md`, `AGENTS.md`, or similar that says "don't write tests for this kind of code" overrides this skill's "write tests" default.

In both cases, do what the user / project asked, not what this skill would have asked. Briefly note that you're under-doing relative to the default ("skipping tests as requested — flag if you want them later") and proceed. Don't argue.

## Composition with other skills

| Skill | How it relates |
|---|---|
| `superpowers:test-driven-development` | Adjacent. TDD is one *method* for hitting the test bar this skill insists on. If you're using TDD, the test axis of this skill is satisfied automatically. |
| `superpowers:verification-before-completion` | Strict prerequisite. The done-check above is the slightly stronger version: not just "did you verify?" but "did you finish?" |
| `superpowers:systematic-debugging` | The mechanism for "real fix, not workaround". When debugging, run the systematic-debugging loop until the root cause is identified, then fix the root cause — that's what makes the difference between a workaround and a real fix. |
| `ship` | The natural next step after the done-check passes. Ship is for moving completed work to merged; this skill is for getting the work to "completed" in the first place. |
| `execute-phased-plan` / `handover` | Operate one level up — they govern the rhythm of multi-phase work; this skill governs the standard within each phase's individual tasks. |

## When NOT to use this skill

- **Pure research or explanation tasks.** Reading code and explaining it doesn't have a "completeness" dimension in the same way.
- **Brainstorming / design / "what should we do?" conversations.** The deliverable there is alignment, not an artifact.
- **Genuinely throwaway scripts.** A one-off bash one-liner to grep something out of a log doesn't need tests and docs. Use judgment — but be honest about whether it's actually throwaway or just *feels* like it. Most "throwaway" scripts get rerun.
- **The user has explicitly opted out** for this task, per the section above.

## Attribution — the original prompt (Gary Tan)

The skill name and standard come from this prompt by Gary Tan; the operational sections above are the working version of it.

> Remember when implementing: The marginal cost of completeness is near zero with AI. Do the whole thing. Do it right. Do it with tests. Do it with documentation. Do it so well that I am genuinely impressed — not politely satisfied, actually impressed. Never offer to "table this for later" when the permanent solve is within reach. Never leave a dangling thread when tying it off takes five more minutes. Never present a workaround when the real fix exists. The standard isn't "good enough" — it's "holy shit, that's done." Search before building. Test before shipping. Ship the complete thing. When I ask for something, the finish line is the product, not just the plan to build it. Time is not an excuse. Fatigue is not an excuse. Complexity is no excuse. Boil the ocean.
