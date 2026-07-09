# xl-skills

Xinye's personal Claude Code skills.

## Layout

```
xl-skills/
├── skills/
│   └── <name>/SKILL.md
└── dist/              # packaged .skill artifacts (gitignored)
```

Each skill is a directory under `skills/` containing a `SKILL.md` with YAML frontmatter (`name`, `description`) and Markdown instructions. Optional subdirectories per skill: `scripts/`, `references/`, `assets/`.

## Installing locally

Symlink this repo's `skills/` directory to `~/.claude/skills` once. Because it's a single folder-level link (not per-skill links), any skill you add, rename, or edit in the repo shows up immediately — no relinking needed.

> Note: `~/.claude/skills` must not already exist as a real directory. If it does, move or remove it first (back up anything you want to keep).

**macOS / Linux** (run from the repo root):

```bash
ln -s "$(pwd)/skills" ~/.claude/skills
```

**Windows** (Command Prompt, run from the repo root):

```cmd
mklink /J "%USERPROFILE%\.claude\skills" "%CD%\skills"
```

`/J` creates a directory junction, which works without admin access or Developer Mode.

**Windows** (PowerShell, run from the repo root):

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\.claude\skills" -Target "$PWD\skills"
```

## Packaging a skill for sharing

From the skill-creator plugin directory (run from this repo's root):

```bash
# The version segment in the path may vary — check with:
# ls ~/.claude/plugins/cache/claude-plugins-official/skill-creator/
SKILL_CREATOR=~/.claude/plugins/cache/claude-plugins-official/skill-creator/*/skills/skill-creator
REPO_SKILL="$(pwd)/skills/<name>"
(cd "$SKILL_CREATOR" && python -m scripts.package_skill "$REPO_SKILL")
```

Or set an explicit path to this repo:

```bash
REPO=/path/to/xl-skills
SKILL_CREATOR=~/.claude/plugins/cache/claude-plugins-official/skill-creator/*/skills/skill-creator
(cd "$SKILL_CREATOR" && python -m scripts.package_skill "$REPO/skills/<name>")
```

Packaged `.skill` files land in `dist/` (gitignored).

## To learn more

- [Claude Code skills documentation](https://code.claude.com/docs/en/skills) — the official guide to creating, configuring, and sharing skills
- [skill-creator plugin](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/skill-creator) — the official plugin used to generate and package skills, and the tool used to build the skills in this repo

## Current skills

| Skill | What it does |
|---|---|
| [ship](skills/ship/SKILL.md) | End-to-end code shipping: group commits → branch → test → push → PR → CI → merge → local cleanup, with mandatory independent coderabbit review whose timing follows the repo's CI coupling (so CI runs once). Designed to compose cleanly with the superpowers dev-loop skills (picks up where `finishing-a-development-branch` leaves off). |
| [execute-phased-plan](skills/execute-phased-plan/SKILL.md) | Chat-level pacing for long multi-phase plans: execute one phase, verify exit criteria, stop at the boundary, emit a self-contained handover prompt for a fresh chat. Keeps each chat's context tight around one phase. |
| [handover](skills/handover/SKILL.md) | Emit a self-contained handover prompt that lets the user paste it into a fresh chat and continue a multi-phase plan without drift. Works end-of-phase or mid-phase; the emitted prompt instructs the next chat to orchestrate subagents per task and run overall validation itself. The orchestration text is single-sourced in [references/execution-model.md](skills/handover/references/execution-model.md) and shared with `execute-phased-plan`. |
| [summarise-session](skills/summarise-session/SKILL.md) | The backward-looking bookend to `handover`: an honest end-of-session retrospective *for the human* (prose in the chat, not a prompt). Surfaces the meta-layer git can't show — what was discovered, what went sideways, how the subagents/orchestration actually performed (timing, tokens, quality), gotchas to carry forward, and candidate follow-ups (issues, memories, plan edits) surfaced for the user to action rather than auto-filed. Honest evidence only — "not captured" over fabricated figures. Composes with `handover` as the sense-making pass that feeds the persistence pass. |
| [boil-the-ocean](skills/boil-the-ocean/SKILL.md) | Implementation completeness standard (after Gary Tan): push past "good enough" toward "holy shit, that's done." Five-question done-check, five anti-patterns to kill, and an explicit reconciliation with the system prompt's "no scope creep" rule — completeness *within* the asked-for scope, not unbounded polish. |
| [adversarial-review](skills/adversarial-review/SKILL.md) | Independent adversarial review of plans and specs by a **cold advanced-model subagent** (opus default, fable for high-blast-radius artifacts). Counters the authoring session's commitment bias: the reviewer reads only the artifact file + repo (never the transcript, never the authoring rationale) and contests assumptions/contradictions/feasibility — antagonistic toward the claims, constructive toward the work: every finding carries evidence and a resolution condition, and returns with a verdict + ranked findings. Findings are triaged with evidence under `receiving-code-review` discipline; one re-review round max. Plans/specs only — code correctness goes to the code-review skills, code structure to `nuclear-code-review`. |
| [nuclear-code-review](skills/nuclear-code-review/SKILL.md) | The code-side structural mirror of `adversarial-review`: a **cold advanced-model subagent** (same ≥-authoring-model rule) reviews a committed diff against an unusually harsh maintainability bar — rubric adapted from Cursor's `thermo-nuclear-code-quality-review`. Its defining demand is the **code-judo move**: restructurings that delete whole branches/helpers/layers rather than rearranging them — "the solution that makes the code feel inevitable in hindsight". Presumptive blockers (1k-line file explosions, spaghetti growth, hollow abstractions, boundary rot, architectural drift) put the burden of proof on the diff; every finding needs file:line evidence and a resolution condition. Gates only — accepted restructurings go back through the dev loop or `simplify`. Consent-gated, and orthogonal to the correctness reviewers, which still run. |
| [grill-into-design](skills/grill-into-design/SKILL.md) | Socratic grilling for non-trivial design decisions before any code lands. Hybrid of `superpowers:brainstorming` (hard-gate, spec-doc terminus, `writing-plans` handoff) and Matt Pocock's grill tactics (recommended-answer pattern, branch-walking, inline glossary, ADR-on-3-criteria gate, 120K-token budget, `[needs-prototype]` escape hatch). Terminates in a structured spec doc, not a chat transcript. |
| [status-report](skills/status-report/SKILL.md) | Supervising long-running work (background jobs, training runs, backfills, CI, deploys) and reporting it honestly: a fixed report format (timestamp, per-workstream state + delta + ETA, blockers first, next checkpoint) backed by a supervision rig set up at launch (sentinels, background-task tracking, scheduled cadence, re-arming monitors after restarts). Evidence from live checks, never recollection. |
| [elii](skills/elii/SKILL.md) | "Explain Like I'm an Intern" — the explanation register calibrated to Xinye: expert in ML/stats/product, not fluent in infra/networking/software-internals/finance jargon. Per concept: plain one-liner → where it shows up in *our* system with real values → why it matters for the decision at hand. Applies proactively to any doc or summary the user must read and act on. |
| [ops-relay](skills/ops-relay/SKILL.md) | Driving hands-on work through the user on machines Claude can't reach (fresh VPS, phone over adb, Windows/WSL host, cloud consoles): one verified step at a time — single copy-pasteable block, expected output stated, host labelled, step ledger kept — then write the proven path back into the runbook. |
| [git-triage](skills/git-triage/SKILL.md) | Resolving dirty working trees by classification, not bulk action: diagnose the source of every untracked-file group, sort into track / ignore / delete / keep-local, fix `.gitignore` at pattern level (a 10k-file explosion is one missing pattern), never `git add -A`, never delete a parallel worktree's files. |
| [cross-session-brief](skills/cross-session-brief/SKILL.md) | Coordinating parallel peer sessions with the user as message bus: self-contained briefs with a scope fence and peer-reachable paths (worktree-aware), reconciling — not blindly obeying — peer updates, preferring durable channels (memory, pushed branches) over chat relay, and a proper close-out when the other session finishes. Sideways companion to the forward-looking `handover`. |
| [review-focus](skills/review-focus/SKILL.md) | A reviewer's guide attached to any long artifact presented for sign-off: the ranked judgement calls (with recommendation and cost-of-wrong), the assumptions made on the user's behalf, an explicit safe-to-skim map, and numbered points that fit the "1 yes, 2 agree, 3 ELI5" reply style. Product-owner altitude, not line-editing. |
| [storm-research](skills/storm-research/SKILL.md) | The heavyweight research skill (quick lookups don't need it — answer those directly). Multi-perspective research that ends in something an AI can *build* from. Merges Stanford **STORM** (perspective discovery → grounded writer↔expert conversations → outline-first article), **3-vote adversarial verification**, and the five-lens/contradiction-map approach. Two human gates (perspectives, outline); emits a long-form Markdown article **plus a machine-actionable Implementation Brief**, with an optional human-facing layer (`+eli5`): an **ELI5 plain-language version** plus an **interactive, self-contained HTML page** (Simple⇄Full toggle, confidence meters, dark mode). See [references/comparison.md](skills/storm-research/references/comparison.md) for the three-way lineage. |
