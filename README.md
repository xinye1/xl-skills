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

Symlink any skill into `~/.claude/skills/` so edits in this repo take effect immediately.

**macOS / Linux** (run from the repo root):

```bash
ln -s "$(pwd)/skills/<name>" ~/.claude/skills/<name>
```

**Windows** (Command Prompt, run from the repo root):

```cmd
mklink /J "%USERPROFILE%\.claude\skills\<name>" "%CD%\skills\<name>"
```

`/J` creates a directory junction, which works without admin access or Developer Mode.

## Installing all skills at once

**macOS / Linux**:

```bash
for dir in skills/*/; do
  ln -s "$(pwd)/$dir" ~/.claude/skills/$(basename "$dir")
done
```

**Windows** (Command Prompt):

```cmd
for /d %d in (skills\*) do mklink /J "%USERPROFILE%\.claude\skills\%~nd" "%CD%\%d"
```

**Windows** (PowerShell):

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\skills" | Out-Null
$repoRoot = $PWD.Path
dir "$repoRoot\skills" | ForEach-Object {
  $link = "$env:USERPROFILE\.claude\skills\$($_.Name)"
  if (-not (Test-Path $link)) {
    New-Item -ItemType Junction -Path $link -Target "$repoRoot\skills\$($_.Name)" | Out-Null
    Write-Host "Linked: $($_.Name)"
  } else {
    Write-Host "Skipped (exists): $($_.Name)"
  }
}
```

## Packaging a skill for sharing

From the skill-creator plugin directory (run from this repo's root):

```bash
# The version segment in the path may vary — check with:
# ls ~/.claude/plugins/cache/claude-plugins-official/skill-creator/
SKILL_CREATOR=~/.claude/plugins/cache/claude-plugins-official/skill-creator/*/skills/skill-creator
(cd "$SKILL_CREATOR" && python -m scripts.package_skill "$(pwd -P)/../../../../../../skills/<name>")
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
| [ship](skills/ship/SKILL.md) | End-to-end code shipping: group commits → branch → test → push → PR → coderabbit review → CI → merge → local cleanup. Designed to compose cleanly with the superpowers dev-loop skills (picks up where `finishing-a-development-branch` leaves off). |
| [execute-phased-plan](skills/execute-phased-plan/SKILL.md) | Chat-level pacing for long multi-phase plans: execute one phase, verify exit criteria, stop at the boundary, emit a self-contained handover prompt for a fresh chat. Keeps each chat's context tight around one phase. |
| [handover](skills/handover/SKILL.md) | Emit a self-contained handover prompt that lets the user paste it into a fresh chat and continue a multi-phase plan without drift. Works end-of-phase or mid-phase; the emitted prompt instructs the next chat to orchestrate subagents per task and run overall validation itself. |
