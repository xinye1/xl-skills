# Upstream: skills from elsewhere, and who builds on these

## This repo is upstream of the Concord delivery kit

The Concord project's delivery kit (delivery-guardrail) copies skills from here and adapts them to
the project. The user, 2026-11-17: "for future instances we should align both and make sure this repo
updates on the skills on this level (applying all project), and the concord project one adapts
changes as appropriate for the project." So a change that applies to every project is made here
first, then ported there by a session working in that repository.

## poteto's pstack: installed as a plugin, not copied

pstack is Lauren Tan's ("poteto") skill set, MIT licensed, published in
[github.com/cursor/plugins](https://github.com/cursor/plugins) (marketplace `cursor-plugins`, plugin
`pstack`, Claude Code variant in `harness/pstack/claude-code/`). It is installed at user scope with
auto-update on (see the README). Installed on 2026-11-17: version 0.15.43, commit `e1cc031`.

Skills here that use it:

| Skill | Uses | How |
|---|---|---|
| `ship` (Step 3b) | `create-verification-skill` (and `maintain-verification-skill`) | The gate drives the change with the repo's `verify-<app>` skill. Verification is a standard step: if pstack isn't installed, or the repo has no verify skill, shipping blocks and asks to set it up. |
| `summarise-session` | `correct` | Offered as a follow-up when the user corrected the same kind of mistake twice. |

**How they are started.** Every pstack skill except `setup-pstack` sets `disable-model-invocation:
true`. Tested on 2026-11-17, the Skill tool refuses: "Skill pstack:create-verification-skill cannot
be used with Skill tool due to disable-model-invocation." So either the user types `/pstack:<name>`,
or, with their go-ahead, Claude reads the installed `SKILL.md` and follows it. The folder is
`installPath` under `pstack@cursor-plugins` in `~/.claude/plugins/installed_plugins.json`. Claude
reads the plugin's `docs/harness/claude-code.md` first; it maps pstack's Cursor names to Claude Code.
This is the route pstack's own Claude Code adapter gives.

**Rule for skills here:** depend on a pstack skill's name and purpose, never on its wording or its
section headings, and don't copy its text. It changes when the source does.

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
and what was given up are in the refinement log, 2026-11-17.
