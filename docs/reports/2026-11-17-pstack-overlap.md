# pstack against xl-skills: overlaps, gaps and what to wire in (2026-11-17)

**Asked.** "for similar skills (I assume e.g. show-me-your-work is similar to summarise-session?) then analyse pros and cons of each, plug any gaps with my own skills if beneficial, then wire in the new skills. don't blindly do so to confuse me and you when skills are invoked and/or abandon any skills that are currently working well."

**Read.** The installed pstack 0.15.43 (commit `e1cc031`), for each skill below, against the xl-skills skill it resembles. A first survey of all 58 pstack skills, by a subagent, picked these candidates (refinement log, 2026-11-17).

**Two facts shape every choice.**

1. A pstack skill can't be started by Claude through the Skill tool (tested). So "wiring in" means one of three things:
   - an xl-skills skill tells Claude to read and follow the installed file at a named moment, with the user's go-ahead;
   - it suggests the user type `/pstack:<name>`;
   - it copies an *idea* into the xl-skills skill's own words (the user's "plug any gaps with my own skills").
2. Nothing here replaces an xl-skills skill. Every xl-skills skill keeps its triggers. A pstack skill is only ever started by a sentence inside an xl-skills skill, or by the user typing it, so there is never a contest over which skill fires.

## Verdicts

| pstack skill | Looks like (xl-skills) | Verdict |
|---|---|---|
| `show-me-your-work` | `summarise-session`, `handover` | **Wire in** for long or unattended runs. It is not a substitute for either. |
| `reflect` | `summarise-session` | **Own words**: its filters go into `summarise-session`. Don't run it: its edit route would copy skills into `~/.claude/skills`. |
| `ketchup` | `status-report`, `elii` | **Leave it.** `/pstack:ketchup` stays available to type. |
| `blast-radius` | `code-review`, `nuclear-code-review` | **Wire in** as an optional offer at `ship` review time. |
| `interrogate` | `adversarial-review` | **Own words**: its "prove it with a run" rule goes into `adversarial-review`. Don't run it: it needs `arena`. |
| `benchmark-checklist`, `principle-explain-the-number` | nothing | **Wire in** at `ship`'s verification gate, for PRs that claim a number. |
| `sharpen` | `grill-into-design` (loosely) | **Leave it.** Different job, typed by the user. |
| `correct` | nothing | Already wired (`summarise-session`, PR #49). |
| `create-` / `maintain-verification-skill` | nothing | Already wired (`ship` Step 3b, PR #49). |

## Each pair

### show-me-your-work vs summarise-session and handover

*What it is.* An append-only TSV decision log written **during** the work. Each row has a timestamp, phase, decision, why, an evidence pointer, and a result. At the end the log is audited against the transcript, and a reviewer on another model writes an "Attention" section.

- **Pros.**
  - It records decisions when they are made, with pointers that resolve. `summarise-session` instead reconstructs them at the end from memory and task notifications. Its own rule, "never fabricate the meta-layer", is easier to keep with a log to read.
  - It suits the long unattended and multi-phase runs that `handover` and `execute-phased-plan` drive.
  - It is the raw material for the user's rule "record the narrative of how and why … decisions and their evidence". The refinement log entry can be written from it.
- **Cons.**
  - It is overhead on short sessions.
  - Its default home is a `decisions.tsv` in the work dir. Removing the worktree would delete it, ignored or not, so it lives outside the repo, at `~/.claude/decision-logs/<repo>/<plan-slug>.tsv`.
  - Its cross-model review asks for "another vendor's model", which Claude Code doesn't offer. The nearest is a different Claude tier.
  - It overlaps `summarise-session`'s honest-retrospective job if both run in full.
- **Decision.**
  - `execute-phased-plan` and the handover execution model start a log for unattended or multi-phase runs.
  - `handover` points the next chat at the log, rather than restating every decision.
  - `summarise-session` reads the log as evidence when one exists.
  - The end-of-run "Attention" review runs only for unattended runs, on a different Claude tier than the author's. `summarise-session` stays the human-facing retrospective.

### reflect vs summarise-session

*What it is.* It mines the transcript for durable lessons and routes each to an edit on a skill the session used. A lesson is kept only if it will still hold in six months, would change what a future agent does, and isn't already in that skill. Anything a lint or script could enforce goes to a backlog. It waits for approval before editing.

- **Pros.** `summarise-session` surfaces gotchas, memories and plan edits, but has no route to "fix the skill that let this happen". `reflect`'s three filters are sharp, and the user's refinement-log habit fits.
- **Cons.** Its edit route is wrong here. It copies the skill folder to `~/.claude/skills/<skill>/`, which is the xl-skills repo, through the symlink. For a pstack skill, that means copying pstack into xl-skills, which the user just ruled out. For an xl-skills skill, it edits the main checkout off-branch. Running it as written would undo today's decision.
- **Decision.** Plug the gap in `summarise-session`, in its own words. Add a "skill edit" candidate kind with reflect's three filters, routed by owner:
  - an xl-skills skill: a branch and `ship`;
  - a pstack skill: never edited; noted as a possible upstream issue;
  - enforceable by a check: `/pstack:correct`.

  It is cited, not copied.

### ketchup vs status-report and elii

*What it is.* A read-only catch-up on what changed since the user's last message. It tells the story in under 100 words, then gives each call waiting on the user, with a link, what it changes, the evidence, the risk and a pick.

- **Pros.** It is good for coming back to a chat after a long unattended stretch.
- **Cons.** It overlaps heavily. `status-report` already leads with "what changed since the last report" and puts blockers first. `elii` already writes every ask as a decision brief (what needs deciding, options, lean). Wiring it in would give two skills that answer "where are we", which is the confusion the user warned against.
- **Decision.** Leave both xl-skills skills as they are, since they work. `/pstack:ketchup` remains available to type.

### blast-radius vs code-review and nuclear-code-review

*What it is.* It finds what a change breaks *outside* the diff: library internals, wire formats, DB columns, flags, code three hops away. Then it proves the one fact the change is safe because of by running real code, on a five-step confidence ladder.

- **Pros.** It is a surface neither reviewer covers. `code-review` and CodeRabbit check the diff. `nuclear-code-review` checks its structure.
- **Cons.**
  - It is extra cost per PR.
  - Its last step runs `arena` (several models in worktrees), which won't run as written here.
  - It writes "through `unslop`", whose dash ban conflicts with this repo's prose.
- **Decision.** In `ship` Step 4, *offer* it next to `nuclear-code-review` (consent-gated, never automatic) for a small diff that touches something shared: a wire format, schema, public API, config flag or library upgrade. Skip its multi-model and `unslop` parts.

### interrogate vs adversarial-review

*What it is.* Adversaries try to break a change or design, and a finding survives only when a run proves it (the command, its output, and the output the intent requires).

- **Pros.** Proof by a run is stronger than a cited `file:line`.
- **Cons.**
  - It is built on `arena`: several worktrees and other models.
  - It covers code changes as well as designs, so it overlaps `adversarial-review` for plans and the review step in `ship` for code.
  - Running both would confuse which review a plan gets.
- **Decision.** Plug the gap in `adversarial-review`'s reviewer brief, in its own words. Where a finding can be shown by a read-only command, the reviewer runs it and pastes the command and output, and says which findings rest on reading alone. The reviewer is already allowed read-only commands.

### benchmark-checklist and principle-explain-the-number: a gap

*What they are.* Seven questions to answer, with evidence, before trusting a performance number: what limits it, whether it was tuned, whether it breaks a physical limit, errors, five alternating runs with the spread, whether it matters end to end, and whether the work happened. For an eval result: whether every run did the task, whether the gap holds across trials and models, and whether the scenario matters.

- **Pros.**
  - Nothing in xl-skills covers this.
  - The user is an ML and statistics expert whose projects make eval and similarity claims.
  - A wrong number in a PR is exactly what a verification gate should catch.
- **Cons.** It is heavy for a one-off ballpark, but the skill itself says one run suffices then.
- **Decision.** At `ship` Step 3b, a PR that claims a measured number (a speedup, a regression, an eval score) has the verifier vet it with `benchmark-checklist` (performance) or `principle-explain-the-number` (eval and other numbers). The PR states the verdict (faster, slower, no measurable difference, or inconclusive) with the run count and spread.

### sharpen vs grill-into-design

*What it is.* It rewrites a task prompt to be deeper rather than bigger: what a top professional would add, the rawest material, their methods, and an outside check.

- **Pros.** It is useful before briefing agents.
- **Cons.** It is a user-side prompt tool with no natural moment inside another skill. `grill-into-design` questions the user and ends in a spec, so they don't compete.
- **Decision.** Not wired. `/pstack:sharpen` is there to type.

## What changes (PR stacked on #49)

- `summarise-session`: read a decision log as evidence; the "skill edit" candidate kind (from `reflect`, own words).
- `execute-phased-plan`, `handover` (both execution models): keep a decision log for unattended or multi-phase runs (`show-me-your-work`, kept outside the repo), and point the next chat at it.
- `ship`: Step 3b vets claimed numbers (`benchmark-checklist`, `principle-explain-the-number`); Step 4 offers `blast-radius`.
- `adversarial-review`: findings shown by a read-only command carry it (from `interrogate`, own words).
- `docs/upstream.md`: the table of what uses pstack.
