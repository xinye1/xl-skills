# Upstream: skills from elsewhere, and who builds on these

## This repo is upstream of the Concord delivery kit

The Concord project's delivery kit (delivery-guardrail) installs these skills as written: its plugin
marketplace lists this repository at a pinned commit, as the plugin `xl-skills`, and its team rules
and user manual tell the team how to use them (delivery-guardrail D15, 2026-11-21). It keeps no
copies. A pin moves by a pull request in the kit, after the owner has read what changed here.

Before that (2026-11-04 to 2026-11-21) the kit copied thirteen skills and adapted them, and changes
were ported by hand. The user, 2026-11-17: "for future instances we should align both and make sure this repo
updates on the skills on this level (applying all project), and the concord project one adapts
changes as appropriate for the project." The first half still holds: a change that applies to every
project is made here. The second half is now done without editing the skills: what is specific to
Concord lives in the kit as a policy the skills read (`ship`'s "project shipping policy"), not as an
adapted copy.

What that means for changes here:

- The team runs whatever commit the kit pins, so a change here reaches them only with the next pin
  bump. A breaking change to how a skill is started or named needs a note for that bump.
- Skills must not assume GitHub where a project may be on another host. `ship` detects the host and
  has `references/azure-devops.md`; `review-focus` points to it.
- Skills must not assume their own bare name: installed as a plugin they are `xl-skills:<name>`.

## poteto's pstack: installed as a plugin, not copied

pstack is Lauren Tan's ("poteto") skill set, MIT licensed, published in
[github.com/cursor/plugins](https://github.com/cursor/plugins) (marketplace `cursor-plugins`, plugin
`pstack`, Claude Code variant in `harness/pstack/claude-code/`). It is installed at user scope and
pinned to a commit (see the README).

**Pinned at:** `7a583913eb1b8d1a0ee76753d1a2cf072e7b54f9` (version 0.15.46), since 2026-11-23. Before: `e58dd04` (0.15.44), from 2026-11-19; `e1cc031` (0.15.43), from 2026-11-17.

### Pinned, and moved only with the owner's go-ahead

The owner, 2026-11-19: "pstack should be pinned. when an update is available the user (I) should be
prompted with "whats new" and ask if they want to run an update on the pin to get the latest.
xl-skill should be automatically applied as I would have been full aware of the implication of any
changes to my projects when I made them."

This replaced auto-update, set on 2026-11-17 (see "How this was decided" below). Two days later
auto-update had already moved pstack to 0.15.44 without anyone seeing the change.

- **The pin** is the full commit SHA in the `ref` of the `cursor-plugins` marketplace in
  `~/.claude/settings.json`. Claude Code checks the marketplace out at that commit. It accepts a full
  40-character SHA there; tested on 2026-11-19. After the `ref` changes, the marketplace has to be
  re-added from the new source (`claude plugin marketplace add cursor/plugins#<sha>`); until then
  Claude Code ignores it and pstack fails to load. `claude plugin update` then moves the plugin to it.
- **`skills/ship/scripts/pstack-pin.sh`** holds those steps:
  - `check` fetches cursor/plugins into a private clone under `~/.cache/xl-skills/pstack-pin/`. It
    reports the pstack commits since the pin, the skills changed, added or removed, which of those
    xl-skills uses, and whether `docs/harness/claude-code.md` (how a skill is started) changed.
  - `check --hook` runs at session start, at most once a day. It speaks only when pstack has changed.
    It asks Claude to tell the owner what's new and ask whether to move the pin.
  - `bump [<sha>]` moves the pin and updates or installs the plugin.
  - `skip` silences one change until a newer one lands.

  Tests: `skills/ship/scripts/test_pstack_pin.sh`, which uses a fake upstream and never touches the
  real settings.
- **A bump is recorded here**, in "Pinned at" above and in the refinement log, through `ship`.
- **xl-skills itself is not pinned.** `~/.claude/skills` links to this checkout, so a merged change
  applies at once, as the owner asked.

Skills here that use it:

| Skill | Uses | How |
|---|---|---|
| `ship` (Step 3b) | `create-verification-skill` (and `maintain-verification-skill`) | The gate drives the change with the repo's `verify-<app>` skill. Verification is a standard step: if pstack isn't installed, or the repo has no verify skill, shipping blocks and asks to set it up. |
| `ship` (Step 3b) | `benchmark-checklist`, `principle-explain-the-number` | A PR that claims a measured number has the verifier check it. |
| `ship` (Step 4) | `blast-radius` | Offered, consent-gated, for a small diff touching something shared. |
| `summarise-session` | `correct` | Offered as a follow-up when the user corrected the same kind of mistake twice. |
| `handover`, `execute-phased-plan`, `summarise-session` | `show-me-your-work` | One append-only decision log per multi-phase or unattended plan, at `~/.claude/decision-logs/<repo>/<plan-slug>.tsv`. It is audited at each phase end, and `summarise-session` reads it as evidence. |

Ideas taken in xl-skills' own words, not by running the pstack skill:

- `summarise-session` takes `reflect`'s three filters for skill edits. Running `reflect` itself would copy skills into `~/.claude/skills`, which is this repo.
- `adversarial-review` takes `interrogate`'s "prove it with a run". Running `interrogate` itself needs `arena`.

Why each was wired, adapted or left alone: [reports/2026-11-17-pstack-overlap.md](reports/2026-11-17-pstack-overlap.md).

**How they are started.** Every pstack skill except `setup-pstack` sets `disable-model-invocation:
true`. Tested on 2026-11-17, the Skill tool refuses: "Skill pstack:create-verification-skill cannot
be used with Skill tool due to disable-model-invocation." So either the user types `/pstack:<name>`,
or, with their go-ahead, Claude reads the installed `SKILL.md` and follows it. The folder is
`installPath` under `pstack@cursor-plugins` in `~/.claude/plugins/installed_plugins.json`. Claude
reads the plugin's `docs/harness/claude-code.md` first; it maps pstack's Cursor names to Claude Code.
This is the route pstack's own Claude Code adapter gives.

**Rule for skills here:** depend on a pstack skill's name and purpose, never on its wording or its
section headings, and don't copy its text. It changes when the pin moves. The list of skills used,
in the table above, is repeated in `pstack-pin.sh` (`DEPENDED_ON`) so its report can flag them; keep
both in step.

### What `ship`'s gate takes from poteto (cited, not copied)

- From the `poteto-mode` Shipping playbook: "Only a verdict from an agent that did not write the
  code counts, because an author checks what it meant to build. Green CI and an approving bot review
  are not verdicts, because neither runs the change as a user would." Hence a fresh verifier subagent
  and the `PASS` / `PASS+NOTES` / `FAIL` verdict.
- Also from Shipping: a verdict covers the code it ran on. Upstream compares `git patch-id`s across
  a rebased stack. `ship` doesn't stack PRs, so it re-verifies when behavior-bearing code changed
  after the verdict.

The gate states its own verdict format and evidence location in the verifier's brief, so it doesn't
depend on what pstack's generator writes.

### How this was decided

The user chose first to copy and adapt `correct` and `create-verification-skill` ("Copy and adapt
(Recommended)", "Both, one skill (Recommended)", "Generator + ship gate (Recommended)"). After the
copies were drafted, they changed course: "i think pstack should be directly downoaded as plugins, and
my related skills such as `ship` should reference and invoke them. this way I won't need to worry
about updating these skills myself, instead just follow any updates from the source." The reasons
and what was given up are in the refinement log, 2026-11-17. Auto-update gave way to the pin on
2026-11-19 (above; refinement log, 2026-11-19).
