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

## Installing a skill locally

Symlink any skill into `~/.claude/skills/`:

```bash
ln -s /home/xinye/repos/xl-skills/skills/<name> ~/.claude/skills/<name>
```

Symlinking (rather than copying) means edits in this repo take effect immediately in every Claude Code session.

## Packaging a skill for sharing

From the skill-creator plugin directory:

```bash
cd ~/.claude/plugins/cache/claude-plugins-official/skill-creator/unknown/skills/skill-creator
python -m scripts.package_skill /home/xinye/repos/xl-skills/skills/<name>
```

Packaged `.skill` files land in `dist/` (gitignored).

## Current skills

| Skill | What it does |
|---|---|
| [ship](skills/ship/SKILL.md) | End-to-end code shipping: group commits → branch → test → push → PR → coderabbit review → CI → merge → local cleanup. Designed to compose cleanly with the superpowers dev-loop skills (picks up where `finishing-a-development-branch` leaves off). |
| [execute-phased-plan](skills/execute-phased-plan/SKILL.md) | Chat-level pacing for long multi-phase plans: execute one phase, verify exit criteria, stop at the boundary, emit a self-contained handover prompt for a fresh chat. Keeps each chat's context tight around one phase. |
| [handover](skills/handover/SKILL.md) | Emit a self-contained handover prompt that lets the user paste it into a fresh chat and continue a multi-phase plan without drift. Works end-of-phase or mid-phase; the emitted prompt instructs the next chat to orchestrate subagents per task and run overall validation itself. |
