#!/usr/bin/env bash
# pstack-pin.sh: keep poteto's pstack plugin pinned, and say when upstream has moved.
#
#   pstack-pin.sh check            report what changed upstream since the pin
#                                  (exit 0 up to date, 10 update available, 1 error)
#   pstack-pin.sh check --hook     the SessionStart hook: at most once per
#                                  PSTACK_PIN_EVERY_SEC; prints hook JSON only when
#                                  an update is available and not skipped; never fails
#   pstack-pin.sh bump [<sha>]     move the pin to <sha> (default: upstream main),
#                                  re-add the marketplace there and update the plugin
#                                  (or install it, on a machine without it)
#   pstack-pin.sh skip [<sha>]     don't raise <sha> (default: the latest pstack
#                                  change upstream) again; a newer change is raised
#
# The pin is the full commit SHA in the `ref` of the cursor-plugins marketplace in
# ~/.claude/settings.json. Claude Code checks the marketplace out at that commit, so
# pstack changes only when this script bumps it, after the owner has seen what's new.
# docs/upstream.md in xl-skills records the pinned commit; a bump is recorded there
# through `ship`.
set -u

SETTINGS=${PSTACK_PIN_SETTINGS:-$HOME/.claude/settings.json}
INSTALLED=${PSTACK_PIN_INSTALLED:-$HOME/.claude/plugins/installed_plugins.json}
UPSTREAM=${PSTACK_PIN_UPSTREAM:-https://github.com/cursor/plugins.git}
REPO_SLUG=${PSTACK_PIN_REPO:-cursor/plugins}
MARKETPLACE=cursor-plugins
PLUGIN=pstack@cursor-plugins
STATE=${PSTACK_PIN_STATE:-$HOME/.cache/xl-skills/pstack-pin}
CLONE=$STATE/cursor-plugins-full.git
EVERY=${PSTACK_PIN_EVERY_SEC:-72000} # 20 hours
CLAUDE=${PSTACK_PIN_CLAUDE:-claude}
# The pstack sources in cursor/plugins. The plugin Claude Code installs is
# harness/pstack/claude-code; pstack/ is where it is written.
PATHS=(pstack harness/pstack)
SHIPPED=harness/pstack/claude-code
# pstack skills that xl-skills skills start or read. Keep in step with the
# "What uses it" table in docs/upstream.md.
DEPENDED_ON=(create-verification-skill maintain-verification-skill correct
	show-me-your-work benchmark-checklist principle-explain-the-number blast-radius)
SELF="bash ~/.claude/skills/ship/scripts/pstack-pin.sh"

die() { echo "pstack-pin: $*" >&2; exit 1; }

to() { # to SECONDS CMD...: run with a time limit where the platform has one
	local s=$1
	shift
	if command -v timeout >/dev/null; then timeout "$s" "$@"
	elif command -v gtimeout >/dev/null; then gtimeout "$s" "$@" # macOS with coreutils
	else "$@"; fi
}

source_ref() { # $1=sha: the 40-char SHA in settings, or empty; $1=any: whatever ref is there
	python3 - "$SETTINGS" "$MARKETPLACE" "$1" <<'EOF'
import json, re, sys
try:
    src = json.load(open(sys.argv[1]))["extraKnownMarketplaces"][sys.argv[2]]["source"]
except (OSError, ValueError, KeyError, TypeError):
    sys.exit(0)
ref = src.get("ref", "")
print(ref if sys.argv[3] == "any" or re.fullmatch(r"[0-9a-f]{40}", ref) else "")
EOF
}
pinned_ref() { source_ref sha; }

installed_sha() { # the commit Claude Code installed pstack from, or empty when not installed
	python3 - "$INSTALLED" "$PLUGIN" <<'EOF'
import json, sys
try:
    entries = json.load(open(sys.argv[1]))["plugins"].get(sys.argv[2]) or []
except (OSError, ValueError, KeyError, TypeError, AttributeError):
    entries = []
print(next((e.get("gitCommitSha") or "unknown" for e in entries if e.get("scope", "user") == "user"), ""))
EOF
}

installed_path() {
	python3 - "$INSTALLED" "$PLUGIN" <<'EOF'
import json, sys
try:
    entries = json.load(open(sys.argv[1]))["plugins"].get(sys.argv[2]) or []
except (OSError, ValueError, KeyError, TypeError, AttributeError):
    entries = []
print(next((e.get("installPath", "") for e in entries if e.get("scope", "user") == "user"), ""))
EOF
}

installed_matches() { # are pstack's installed files the shipped plugin at commit $1?
	local dir tmp d rc=0
	dir=$(installed_path)
	[ -n "$dir" ] && [ -d "$dir" ] || return 1
	tmp=$(mktemp -d) || return 1
	git --git-dir="$CLONE" archive "$1" "$SHIPPED" | tar -x -C "$tmp" || rc=1
	for d in skills docs agents; do # not the whole folder: Claude Code adds markers such as .in_use
		[ $rc = 0 ] || break
		if [ -e "$tmp/$SHIPPED/$d" ] || [ -e "$dir/$d" ]; then
			diff -rq "$tmp/$SHIPPED/$d" "$dir/$d" >/dev/null 2>&1 || rc=1
		fi
	done
	rm -rf "$tmp"
	return $rc
}

FETCH_TIMEOUT=120
fetch() { # bring the private clone up to date with upstream main
	mkdir -p "$STATE"
	if [ ! -d "$CLONE" ]; then
		# Clone into a folder of our own, then rename it into place: a cut-off
		# clone leaves nothing, and when two sessions race, the first rename wins.
		local part
		part=$(mktemp -d "$STATE/clone.XXXXXX") || return 1
		if to "$FETCH_TIMEOUT" git clone -q --bare "$UPSTREAM" "$part/c" 2>/dev/null; then
			python3 -c 'import os, sys; os.rename(sys.argv[1], sys.argv[2])' "$part/c" "$CLONE" 2>/dev/null
		fi
		rm -rf "$part"
		[ -d "$CLONE" ] || return 1
	fi
	to "$FETCH_TIMEOUT" git -C "$CLONE" fetch -q origin '+refs/heads/main:refs/heads/main' 2>/dev/null
}

version_at() { # plugin version at a commit
	git -C "$CLONE" show "$1:$SHIPPED/plugin.json" 2>/dev/null |
		python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("version","?"))
except ValueError: print("?")'
}

latest_change() { git -C "$CLONE" log -1 --format=%H main -- "${PATHS[@]}"; }

report() { # what's new between the pin ($1) and upstream main, as Markdown
	local pin=$1 head
	head=$(git -C "$CLONE" rev-parse main)
	echo "pstack: pinned ${pin:0:7} (v$(version_at "$pin")); upstream main ${head:0:7} (v$(version_at "$head"))."
	echo
	echo "Changes to pstack since the pin, newest first:"
	git -C "$CLONE" log --no-merges --date=short --format='- %h %ad %s' -n 30 "$pin..main" -- "${PATHS[@]}"
	local n
	n=$(git -C "$CLONE" rev-list --no-merges --count "$pin..main" -- "${PATHS[@]}")
	[ "$n" -gt 30 ] && echo "- … and $((n - 30)) more"
	echo
	local changed added removed used=()
	changed=$(git -C "$CLONE" diff --no-renames --name-only "$pin" main -- "$SHIPPED/skills" |
		sed -n "s|^$SHIPPED/skills/\([^/]*\)/.*|\1|p" | sort -u)
	added=$(git -C "$CLONE" diff --no-renames --name-status --diff-filter=A "$pin" main -- "$SHIPPED/skills" |
		sed -n "s|^A\t$SHIPPED/skills/\([^/]*\)/SKILL.md$|\1|p")
	removed=$(git -C "$CLONE" diff --no-renames --name-status --diff-filter=D "$pin" main -- "$SHIPPED/skills" |
		sed -n "s|^D\t$SHIPPED/skills/\([^/]*\)/SKILL.md$|\1|p")
	local s
	for s in "${DEPENDED_ON[@]}"; do grep -qx "$s" <<<"$changed" && used+=("$s"); done
	echo "Skills changed: $(echo $changed | sed 's/ /, /g')"
	[ -n "$added" ] && echo "Skills added: $(echo $added | sed 's/ /, /g')"
	[ -n "$removed" ] && echo "Skills removed: $(echo $removed | sed 's/ /, /g')"
	if [ ${#used[@]} -gt 0 ]; then
		echo "Of these, xl-skills uses: ${used[*]}"
	else
		echo "None of the skills xl-skills uses changed."
	fi
	git -C "$CLONE" diff --quiet "$pin" main -- "$SHIPPED/docs/harness/claude-code.md" ||
		echo "docs/harness/claude-code.md changed (how a pstack skill is started from Claude Code)."
	echo
	echo "Compare: https://github.com/$REPO_SLUG/compare/${pin:0:12}...${head:0:12}"
}

cmd_check() {
	local hook=0
	[ "${1:-}" = --hook ] && hook=1
	local pin
	pin=$(pinned_ref)
	if [ -z "$pin" ]; then
		[ $hook = 1 ] && exit 0
		die "no pinned commit for $MARKETPLACE in $SETTINGS (expected a 40-char SHA in source.ref)"
	fi
	if [ $hook = 1 ]; then
		local stamp=$STATE/last-check now last
		now=$(date +%s)
		last=$(cat "$stamp" 2>/dev/null || echo 0)
		[ $((now - last)) -lt "$EVERY" ] && exit 0
		mkdir -p "$STATE" && echo "$now" >"$stamp"
		FETCH_TIMEOUT=20 # a session start must not hang on the network
		fetch || exit 0
	else
		fetch || die "could not fetch $UPSTREAM"
	fi
	git -C "$CLONE" cat-file -e "$pin^{commit}" 2>/dev/null || {
		[ $hook = 1 ] && exit 0
		die "pinned commit $pin is not on upstream main"
	}
	local latest
	latest=$(latest_change)
	if [ -z "$latest" ] || git -C "$CLONE" merge-base --is-ancestor "$latest" "$pin"; then
		[ $hook = 1 ] || echo "pstack is up to date at ${pin:0:7} (v$(version_at "$pin"))."
		exit 0
	fi
	if [ $hook = 0 ]; then
		report "$pin"
		exit 10
	fi
	[ "$(cat "$STATE/skipped" 2>/dev/null)" = "$latest" ] && exit 0
	local head
	head=$(git -C "$CLONE" rev-parse main)
	report "$pin" | python3 -c '
import json, sys
body, head, self_, latest = sys.stdin.read(), sys.argv[1], sys.argv[2], sys.argv[3]
ctx = ("A newer pstack is available upstream; the pin has not moved.\n\n" + body +
       "\n\nIn your first reply, before anything else, tell the owner in plain words what is new"
       " (from the list above, and the changed skills that xl-skills uses, read from the compare link"
       " if needed) and ask whether to move the pin to " + head[:7] + "."
       " On yes: run `" + self_ + " bump " + head + "`, tell them to restart Claude Code, then record"
       " the new pin in xl-skills docs/upstream.md and the refinement log through `ship`."
       " On no: run `" + self_ + " skip " + latest + "`. Not now: do nothing; it is raised again tomorrow.")
first = body.splitlines()[0]
print(json.dumps({"systemMessage": "pstack update available. " + first + " Claude will ask whether to move the pin.",
                  "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ctx}}))
' "$head" "$SELF" "$latest"
	exit 0
}

LOCK_DIR=
lock() { # one bump at a time on this machine; mkdir is atomic everywhere
	LOCK_DIR=$STATE/bump.lock.d
	local waited=0
	until mkdir "$LOCK_DIR" 2>/dev/null; do
		[ $waited -ge 600 ] && die "another bump has held $LOCK_DIR for 10 minutes (remove it if none is running)"
		sleep 1
		waited=$((waited + 1))
	done
	trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
}

entry() { # entry save FILE | pin SHA | restore FILE: the cursor-plugins entry in settings, and only it
	python3 - "$SETTINGS" "$MARKETPLACE" "$REPO_SLUG" "$@" <<'EOF'
import json, os, sys
path, name, repo, action, arg = sys.argv[1:]
d = json.load(open(path)) if os.path.exists(path) else {}  # malformed JSON still fails
markets = d.setdefault("extraKnownMarketplaces", {})
if action == "save":  # written in full before settings change, or the bump stops here
    tmp = arg + ".tmp"
    with open(tmp, "w") as f:
        json.dump(markets.get(name), f)
    os.replace(tmp, arg)
    sys.exit(0)
if action == "pin":
    m = markets.setdefault(name, {})
    m.setdefault("source", {"source": "github", "repo": repo})["ref"] = arg
    m.pop("autoUpdate", None)  # a pinned marketplace moves only by bump
else:  # restore: other keys may have changed meanwhile (another session), so leave them
    before = json.load(open(arg))
    if before is None:
        markets.pop(name, None)
    else:
        markets[name] = before
    if not markets:
        d.pop("extraKnownMarketplaces")
mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o600
tmp = path + ".pstack-pin.tmp"
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)  # never readable by others, even briefly
with os.fdopen(fd, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
os.chmod(tmp, mode)  # keep the file's own permissions
os.replace(tmp, path)
EOF
}

cmd_bump() {
	local target=${1:-}
	fetch || die "could not fetch $UPSTREAM"
	[ -z "$target" ] && target=$(git -C "$CLONE" rev-parse main)
	target=$(git -C "$CLONE" rev-parse --verify -q "$target^{commit}") || die "unknown commit: ${1:-}"
	git -C "$CLONE" merge-base --is-ancestor "$target" main || die "$target is not on upstream main"
	mkdir -p "$STATE" "$(dirname "$SETTINGS")"
	# One bump at a time on this machine, from reading the old state to the end:
	# a rollback must not undo another session's finished bump.
	lock
	local old prev had_entry=0 was_installed saved=$STATE/entry.before-bump.json
	old=$(pinned_ref)
	prev=$(source_ref any)
	was_installed=$(installed_sha)
	entry save "$saved" || die "could not save the current entry; settings unchanged"
	[ "$(cat "$saved")" = null ] || had_entry=1
	entry pin "$target" || die "could not write $SETTINGS"
	# On a failure past this point, put the entry back and re-register the
	# marketplace from it: a settings source that doesn't match the registered
	# one makes Claude Code ignore the marketplace, and pstack fails to load.
	rollback() {
		echo "pstack-pin: $1; putting the previous pin back" >&2
		local back=ok now
		entry restore "$saved" || back=failed
		if [ -n "$prev" ]; then
			"$CLAUDE" plugin marketplace add "$REPO_SLUG#$prev" || back=failed
		elif [ "$had_entry" = 1 ]; then
			"$CLAUDE" plugin marketplace add "$REPO_SLUG" || back=failed
		else
			"$CLAUDE" plugin marketplace remove "$MARKETPLACE" --scope user || back=failed
		fi
		# A failed step may still have changed the plugin: put back what was installed.
		now=$(installed_sha)
		if [ -z "$was_installed" ]; then
			[ -z "$now" ] || "$CLAUDE" plugin uninstall "$PLUGIN" --scope user || back=failed
		elif [ "$now" != "$was_installed" ] ||
			{ [ "$was_installed" != unknown ] && ! installed_matches "$was_installed"; }; then
			[ -z "$now" ] || "$CLAUDE" plugin uninstall "$PLUGIN" --scope user
			"$CLAUDE" plugin install "$PLUGIN" --scope user || back=failed
		fi
		[ $back = ok ] || die "rollback incomplete; check the cursor-plugins entry in $SETTINGS (it was: $(cat "$saved")), then run: $CLAUDE plugin marketplace add $REPO_SLUG${prev:+#$prev}${was_installed:+ && $CLAUDE plugin install $PLUGIN --scope user}"
		die "$1; the pin is unchanged${old:+ at ${old:0:7}}"
	}
	# A source change has to be re-added before Claude Code uses it again.
	"$CLAUDE" plugin marketplace add "$REPO_SLUG#$target" || rollback "marketplace add failed"
	if [ -n "$was_installed" ]; then
		"$CLAUDE" plugin update "$PLUGIN" --scope user || rollback "plugin update failed"
	else
		"$CLAUDE" plugin install "$PLUGIN" --scope user || rollback "plugin install failed"
	fi
	# Claude Code keeps the cached files when the plugin's version string is
	# unchanged, so check the commit it recorded and the files themselves, and
	# reinstall if it kept the old ones.
	if [ "$(installed_sha)" != "$target" ] || ! installed_matches "$target"; then
		"$CLAUDE" plugin uninstall "$PLUGIN" --scope user && "$CLAUDE" plugin install "$PLUGIN" --scope user ||
			rollback "reinstalling at the new pin failed"
		[ "$(installed_sha)" = "$target" ] && installed_matches "$target" ||
			rollback "pstack's installed files are not the ones at $target"
	fi
	rm -f "$STATE/skipped"
	echo "pstack pin: ${old:0:7} (v$(version_at "${old:-$target}")) -> ${target:0:7} (v$(version_at "$target")). Restart Claude Code to load it."
	echo "Record it: docs/upstream.md in xl-skills, \"Pinned at\", through ship."
}

cmd_skip() {
	local sha=${1:-}
	if [ -z "$sha" ]; then
		[ -d "$CLONE" ] || fetch || die "could not fetch $UPSTREAM"
		sha=$(latest_change)
	fi
	mkdir -p "$STATE" && echo "$sha" >"$STATE/skipped"
	echo "Won't raise pstack ${sha:0:7} again; a newer change will be raised."
}

case "${1:-check}" in
check) shift || true; cmd_check "$@" ;;
bump) shift; cmd_bump "$@" ;;
skip) shift; cmd_skip "$@" ;;
*) die "usage: pstack-pin.sh check [--hook] | bump [<sha>] | skip [<sha>]" ;;
esac
