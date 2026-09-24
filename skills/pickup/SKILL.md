---
name: pickup
description: Use when the user types /pickup, or says "pick up the handover", "load the handover", "resume from the handover", "continue from the last handover", "what handovers are waiting", "list my handovers" — usually as the first message of a fresh chat (after /clear, or a new `claude`) following a `handover`. Lists the repo's waiting handovers from ~/.claude/handovers/, loads the chosen one in full as this chat's brief, and archives it. Not for reopening a raw past session — that's /resume.
argument-hint: "[all | <search text>]"
---

# Pickup — load a saved handover into a fresh chat

`handover` saves a self-contained prompt to `~/.claude/handovers/<repo>/`. This skill is the receiving half: it finds that file, loads it verbatim, and starts on it, so the user never copies text between sessions. The usual flow is `handover` → `/clear` → `/model <recommended>` (only when the handover's receipt says the chat is on the wrong model) → `/pickup`, all in one terminal. It works just as well days later, or after a reboot, in any new session in that repo (`claude --model <recommended>`, then `/pickup`). `/clear` wipes the handover's receipt from the screen, and a reboot loses it entirely, so this skill checks the model itself before loading anything (Step 2).

Keep the user able to see every step: what's waiting, which handover was loaded, where the file went, and anything that looks off. The handover carries context the user can't afford to lose, so it is never deleted, and it is never summarised on the way in.

## Step 1: List the queue

```bash
root="$HOME/.claude/handovers"
c=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && repo=$(basename "$(dirname "$c")") || repo=$(basename "$PWD")
echo "repo: $repo  cwd: $PWD"
ls -r "$root/$repo"/*.md 2>/dev/null | while IFS= read -r f; do
  echo "$(basename "$f") | $(sed -n 's/^title: //p' "$f" | head -1) | model $(sed -n 's/^model: //p' "$f" | head -1) | branch $(sed -n 's/^branch: //p' "$f" | head -1) | $(sed -n 's/^kind: //p' "$f" | head -1)"
done
echo "other repos waiting:"; for d in "$root"/*/; do n=$(ls "$d"*.md 2>/dev/null | wc -l); [ "$n" -gt 0 ] && [ "$(basename "$d")" != "$repo" ] && echo "  $(basename "$d"): $n"; done
echo "recently picked up:"; ls -r "$root/$repo/picked-up"/*.md 2>/dev/null | head -3 | while IFS= read -r f; do basename "$f"; done
```

Files named `YYYY-MM-DD-HHMM-…` sort newest first by name. Pending handovers sit directly in `<repo>/`; used ones are in `<repo>/picked-up/`.

## Step 2: Choose

Arguments passed: "$ARGUMENTS" (empty quotes mean none). They decide the path:

- **Empty.** Use this repo's pending queue.
  - **None waiting:** say so and show the "other repos" and "recently picked up" lines, so the user can see where things are. Offer to reload a recent one. Stop there.
  - **Exactly one:** load it. No question needed; the receipt in Step 4 shows what was loaded.
  - **Two or more:** let the user pick, newest first. Use AskUserQuestion with up to four options: label = the short title; description = age ("2h ago", "3 days ago"), model, branch, kind. With more than four, print a numbered table instead and ask for the number. Never silently take the newest; parallel phases and abandoned hops both leave several waiting.
- **`all`.** List pending handovers across every repo, grouped by repo, then pick the same way.
- **Any other text.** Match it against filenames and titles in this repo's pending and `picked-up/` files, then every repo's if there's no match. One match loads; several means the user picks. This is how an already-used handover gets reloaded.

**Model gate, before loading.** Take the chosen file's `model` field (the Step 1 listing already shows it) and compare it, by tier (`haiku` < `sonnet` < `opus` < `fable`), with the model you are running as:
- **This chat is weaker:** stop here. Don't read the rest of the file, and don't archive it. Say:
  > This handover wants `<model>`, but this chat is on `<current>`. Run `/model <model>`, then `/pickup <file name without .md>`. Or reply "continue" to load it on `<current>` anyway.

  Switching now means the full handover goes to the right model the first time. Loading it first and switching afterwards makes the model re-read the whole context at full price, because the prompt cache is per model. On "continue", go on to Step 3. The handover's own first-action check still decides whether its template can run on this model.
- **Same tier, stronger, or you can't tell:** go on. The receipt's `model` line says which.

## Step 3: Load it in full

Read the whole file with the Read tool. Never summarise it or skim it, and never read only the frontmatter. Then run the checks the user would want before trusting it:

- **Staleness:** count commits since the handover was written, on this checkout (`git log --oneline --since="<written>" | wc -l`) and, when the frontmatter `branch` exists here (`git rev-parse --verify --quiet <branch>`, or `origin/<branch>`), on that branch too. A handover written for another worktree's branch can go stale without touching this checkout's history. If commits have landed, its status section may be out of date: say how many and on which ref, and verify the claims that matter before relying on them. For a `mid-phase` handover, also run `git status --short` (in its `cwd` if that exists) and compare it with the uncommitted work the handover lists, since a commit count can't show edits that were never committed.
- **Location:** if the frontmatter `cwd` differs from `$PWD` (another worktree, or a new machine), check that the plan path the handover names exists. If it doesn't, tell the user before starting, and ask where the plan lives now.
- **Model:** already gated in Step 2. Carry the result to the receipt's `model` line.

## Step 4: Archive it, show the receipt

Only after the full read succeeded, move the file, then stamp the archived copy. Nothing is deleted. Moving first means a failed move leaves the file exactly as it was, still `pending`.

1. Move it, and prove the move worked:
   ```bash
   f="<pending file>"; a="$(dirname "$f")/picked-up"; mkdir -p "$a"
   mv -n "$f" "$a/" && test -f "$a/$(basename "$f")" && ! test -e "$f" && echo "ok: archived" || echo "FAIL: not archived"
   ```
2. Only on `ok: archived`, stamp the archived file with the Edit tool (portable, unlike `sed -i`). Replace the frontmatter line `status: pending` with:
   ```yaml
   status: picked-up
   picked_up: <YYYY-MM-DDTHH:MM, local time>
   picked_up_by: ${CLAUDE_SESSION_ID}
   ```

Skip both when the chosen file is already in `picked-up/` (a reload). If the move fails, say so and skip the stamp. The usual cause is that `picked-up/` already holds a file with the same name, which `mv -n` never overwrites. The file stays in the pending queue, untouched, which is harmless: it will be offered again next time.

Then print the receipt, with every line backed by a check above:

```text
✓ Picked up — <title>
  file      ~/.claude/handovers/<repo>/picked-up/<name>.md   (<L> lines, read in full)
  written   <YYYY-MM-DD HH:MM> (<age>) · branch <branch> · <kind> · from session <from_session>
  model     handover wants <model> · this chat is on <current>   ✓ | ⚠ higher than needed | ⚠ loaded on a weaker model at your request
  fresh?    ✓ no commits since written | ⚠ <N> commits since written on <ref>; re-verifying status
  archived  ✓ moved to picked-up/ (reload any time: /pickup <search text>)
  waiting   <W> other handover(s) for <repo>
```

## Step 5: Start on it

Treat the handover body as the user's opening brief, exactly as if they had pasted it, and begin with its first action, which is the model check. From here the handover's own instructions govern. `execute-phased-plan` recognises a chat that opened with `/pickup` as a handover-launched chat and runs the phase here, without emitting another handover first.

## Anti-patterns

| Anti-pattern | Why it burns the user |
|---|---|
| Summarising or partly reading the handover | The handover was written to be self-contained, and every section is there on purpose. A skim loses exactly the guardrail or deviation the next hour of work needed. |
| Deleting a used handover | The user is counting on never losing these notes. Archive to `picked-up/`, never `rm`; an archived file costs nothing and can be reloaded. |
| Taking the newest silently when several are waiting | Parallel phases and abandoned hops both leave more than one waiting. Picking the wrong one starts the wrong phase from the wrong status. |
| Loading silently, with no receipt | The user ran `/clear` trusting the handover would come through. The receipt is their proof it did, and it shows which one loaded and whether anything looks stale. |
| Trusting the status section when commits have landed since | The handover is a snapshot. If `main` moved after it was written, the "merged / passing" claims need rechecking before they steer the work. |
| Loading the handover before checking the model | After `/clear` or a reboot, the handover's receipt is gone from the screen, so this skill is the last reminder to switch. Loading on a weaker model first means reading the whole handover twice, the second time at full price on the new model, and the file gets archived before the chat can properly run it. |
| Archiving before the full read | If the read fails after the move, the handover drops out of the pending list without having been used. Read first, archive second. |

## When NOT to use

- Reopening a past conversation itself: that's `/resume` (or `claude --resume <id>`). Each handover records its `from_session` for exactly this.
- Coordinating with a live parallel session: that's `cross-session-brief`.
- The user pasted a handover directly into the chat: it's already loaded, so just start on it.
