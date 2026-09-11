# Deep modules — the vocabulary

The design language for `deepen-architecture`. Read before surveying; use these words exactly in every candidate, card, and conversation. Folded in from Matt Pocock's `codebase-design` skill (`SKILL.md` + `DEEPENING.md`), which the upstream `improve-codebase-architecture` depends on.

Consistent language is the whole point: "we should clean up the order service" is a sentence two people can agree on while picturing different changes. "The Order intake module is shallow — its interface is nearly as complex as its implementation" is not.

## Glossary

**Module** — anything with an interface and an implementation. Deliberately scale-agnostic: a function, a class, a package, a tier-spanning slice. *Avoid:* unit, component, service.

**Interface** — everything a caller must know to use the module correctly: the type signature, but *also* invariants, ordering constraints, error modes, required configuration, performance characteristics. *Avoid:* API, signature — both too narrow, they mean only the type-level surface.

**Implementation** — what's inside the module. Distinct from **adapter**: a thing can be a small adapter with a large implementation (a Postgres repo) or a large adapter with a small implementation (an in-memory fake). Say "adapter" when the seam is the topic, "implementation" otherwise.

**Depth** — leverage at the interface: how much behaviour a caller or test can exercise per unit of interface they must learn. **Deep** = a lot of behaviour behind a small interface. **Shallow** = the interface is nearly as complex as the implementation.

**Seam** *(Feathers)* — a place where behaviour can be altered without editing in that place; the *location* where a module's interface lives. Where the seam goes is a design decision distinct from what sits behind it. *Avoid:* boundary — overloaded with DDD's bounded context.

**Adapter** — a concrete thing satisfying an interface at a seam. Names a *role* (which slot it fills), not a substance (what's inside it).

**Leverage** — what callers get from depth: more capability per unit of interface learned. One implementation pays back across N call sites and M tests.

**Locality** — what maintainers get from depth: change, bugs, knowledge, and verification concentrate in one place instead of spreading across callers. Fix once, fixed everywhere.

## Deep vs shallow

```
DEEP                          SHALLOW  (avoid)
┌──────────────────┐          ┌────────────────────────────┐
│  small interface │          │      large interface       │
├──────────────────┤          ├────────────────────────────┤
│                  │          │   thin implementation      │
│      lots of     │          └────────────────────────────┘
│  implementation  │
│                  │
└──────────────────┘
```

Interrogating an interface: can I reduce the number of methods? Can I simplify the parameters? Can I hide more complexity inside?

## Principles

**Depth is a property of the interface, not the implementation.** A deep module can be internally composed of small, swappable parts — they simply aren't part of its interface. A module may have *internal* seams (private, used by its own tests) as well as the *external* seam at its interface.

**The deletion test.** Imagine the module deleted. If complexity vanishes, it was a pass-through — deleting it *is* the improvement. If complexity reappears across N callers, it was earning its keep — deepening it is. This is the filter that separates a candidate from a smell.

**The interface is the test surface.** Callers and tests cross the same seam. Wanting to test *past* the interface means the module is the wrong shape.

**One adapter means a hypothetical seam. Two adapters means a real one.** Don't introduce a port unless something actually varies across it — typically production plus test. A single-adapter seam is indirection with better branding.

**Rejected framings.** Depth as a ratio of implementation-lines to interface-lines (Ousterhout's original) rewards padding the implementation — use depth-as-leverage. "Interface" as the TypeScript `interface` keyword or a class's public methods is too narrow. "Boundary" is taken.

## Dependency categories

Classify a candidate's dependencies — the category determines how the deepened module gets tested across its seam, and whether a port is justified at all.

| Category | What it is | Deepening shape |
|---|---|---|
| **In-process** | Pure computation, in-memory state, no I/O | Always deepenable. Merge the modules, test through the new interface directly. No adapter. |
| **Local-substitutable** | Has a local test stand-in (PGLite for Postgres, in-memory filesystem) | Deepenable if the stand-in exists. Test with it running in the suite. The seam is *internal* — no port at the external interface. |
| **Remote but owned** | Your own services across a network (internal APIs, microservices) | Define a **port** at the seam. The deep module owns the logic; the transport is an injected adapter — HTTP/gRPC/queue in production, in-memory in tests. |
| **True external** | Third parties you don't control (Stripe, a broker API) | Injected port, mock adapter in tests. |

Phrase a remote-but-owned recommendation as: *"Define a port at the seam, HTTP adapter for production and in-memory adapter for tests, so the logic sits in one deep module even though it deploys across a network."*

## Testing strategy: replace, don't layer

- Old unit tests on the shallow modules become waste once tests exist at the deepened module's interface. **Delete them** — keeping both is how a deepening turns into a net increase in code.
- Write the new tests at the deepened module's interface. The interface is the test surface.
- Assert on observable outcomes through the interface, never on internal state.
- Tests should survive internal refactors. A test that must change when the implementation changes is testing past the interface — that's a finding about the seam, not about the test.
