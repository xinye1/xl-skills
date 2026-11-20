#!/usr/bin/env bash
# Tests for pstack-pin.sh against a local fake upstream and a fake `claude`;
# no network, and the real ~/.claude/settings.json is never read or written.
set -u
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fails=0
check() { # check NAME CONDITION...
	local name=$1
	shift
	if "$@"; then echo "ok   $name"; else echo "FAIL $name"; fails=$((fails + 1)); fi
}

# The fake upstream: the cursor/plugins layout, with pstack's shipped plugin.
up=$tmp/up
git init -q -b main "$up"
g() { git -C "$up" -c user.name=t -c user.email=t@t "$@"; }
ship=$up/harness/pstack/claude-code
put() { mkdir -p "$(dirname "$1")" && echo "$2" >"$1"; }
commit() { g add -A && g commit -q -m "$1" && g rev-parse HEAD; }
put "$ship/plugin.json" '{"name":"pstack","version":"0.1.0"}'
put "$ship/skills/correct/SKILL.md" v1
put "$ship/skills/arena/SKILL.md" v1
put "$ship/docs/harness/claude-code.md" v1
A=$(commit "pstack 0.1.0")

mkdir "$tmp/bin"
# The fake CLI logs each call. It registers the marketplace at the ref it is
# given, and installs or updates pstack from that commit (an update keeps the old
# commit when STALE=1, as Claude Code does when the version string is unchanged).
cat >"$tmp/bin/claude" <<'FAKE'
#!/usr/bin/env bash
echo "$*" >>"$CLAUDE_LOG"
if [ "${TOUCH:-0}" = 1 ] && [ "$1 $2" = "plugin update" ]; then # another session changes an unrelated setting meanwhile
	python3 -c "import json,sys; d=json.load(open(sys.argv[1])); d['model']='sonnet'; json.dump(d, open(sys.argv[1],'w'))" "$PSTACK_PIN_SETTINGS"
fi
case "$*" in ${FAIL_ON:-no-such-call}) exit 1 ;; esac
put() { # record pstack as installed from commit $1 (none if empty), with its files in a cache folder
	if [ -n "$1" ]; then
		local dir=$CACHE/$1
		rm -rf "$dir" && mkdir -p "$dir"
		git -C "$UP" archive "$1" harness/pstack/claude-code | tar -x -C "$dir" --strip-components 3
		echo "{\"plugins\":{\"pstack@cursor-plugins\":[{\"scope\":\"user\",\"installPath\":\"$dir\",\"gitCommitSha\":\"$1\"}]}}"
	else echo '{"plugins":{}}'; fi >"$PSTACK_PIN_INSTALLED"
}
case "$*" in
"plugin marketplace add "*) ref=${4#*#}; [ "$ref" = "$4" ] && ref=main; git -C "$UP" rev-parse "$ref" >"$MKT" ;;
"plugin marketplace remove "*) rm -f "$MKT" ;;
"plugin update "*)
	[ "${STALE:-0}" = 1 ] || put "$(cat "$MKT")" ;;
"plugin install "*) put "$(cat "$MKT")" ;;
"plugin uninstall "*) put "" ;;
esac
FAKE
chmod +x "$tmp/bin/claude"
export MKT=$tmp/mkt CACHE=$tmp/cache UP=$up CLAUDE_LOG=$tmp/claude.log PSTACK_PIN_UPSTREAM=$up PSTACK_PIN_STATE=$tmp/state \
	PSTACK_PIN_SETTINGS=$tmp/settings.json PSTACK_PIN_CLAUDE=$tmp/bin/claude \
	PSTACK_PIN_INSTALLED=$tmp/installed.json
installed() { # as if pstack were installed from commit $1, the way the fake CLI records it
	local dir=$CACHE/$1
	rm -rf "$dir" && mkdir -p "$dir"
	git -C "$up" archive "$1" harness/pstack/claude-code | tar -x -C "$dir" --strip-components 3
	echo "{\"plugins\":{\"pstack@cursor-plugins\":[{\"scope\":\"user\",\"installPath\":\"$dir\",\"gitCommitSha\":\"$1\"}]}}" >"$tmp/installed.json"
}
pin() { # write settings pinning $1 (empty: no ref), with autoUpdate on
	python3 - "$tmp/settings.json" "$1" <<'EOF'
import json, sys
src = {"source": "github", "repo": "cursor/plugins"}
if sys.argv[2]:
    src["ref"] = sys.argv[2]
json.dump({"model": "opus", "extraKnownMarketplaces": {"cursor-plugins": {"source": src, "autoUpdate": True}}},
          open(sys.argv[1], "w"))
EOF
}
run() { "$here/pstack-pin.sh" "$@" >"$tmp/out" 2>"$tmp/err"; echo $? >"$tmp/rc"; }
rc() { [ "$(cat "$tmp/rc")" = "$1" ]; }
out_has() { grep -qF -- "$1" "$tmp/out"; }
out_empty() { [ ! -s "$tmp/out" ]; }
same_json() { python3 -c "import json,sys; sys.exit(json.load(open(sys.argv[1])) != json.load(open(sys.argv[2])))" "$1" "$2"; }
hook() { rm -f "$tmp/state/last-check"; run check --hook; }

# no pin: the hook stays quiet, check says why
pin ""
run check --hook
check "no pin: hook is quiet" eval 'rc 0 && out_empty'
run check
check "no pin: check fails" rc 1

# pinned at the latest pstack change
pin "$A"
installed "$A"
echo "$A" >"$MKT"
run check
check "up to date" eval 'rc 0 && out_has "up to date at ${A:0:7} (v0.1.0)"'
hook
check "up to date: hook is quiet" eval 'rc 0 && out_empty'

# a change elsewhere in the monorepo is not a pstack update
put "$up/other/README.md" x
commit "other plugin" >/dev/null
run check
check "unrelated change: up to date" rc 0

# a pstack change to a skill xl-skills does not use
put "$ship/skills/arena/SKILL.md" v2
put "$ship/plugin.json" '{"name":"pstack","version":"0.1.1"}'
B=$(commit "chore(pstack): arena tweak")
run check
check "update: exit 10" rc 10
check "update: versions" out_has "pinned ${A:0:7} (v0.1.0); upstream main ${B:0:7} (v0.1.1)"
check "update: lists the commit" out_has "chore(pstack): arena tweak"
check "update: changed skills" out_has "Skills changed: arena"
check "update: none used" out_has "None of the skills xl-skills uses changed."
check "update: harness doc unchanged" eval '! out_has "claude-code.md changed"'

# a change to a skill xl-skills uses, a new skill, and the harness doc
put "$ship/skills/correct/SKILL.md" v2
put "$ship/skills/sharpen/SKILL.md" v1
put "$ship/docs/harness/claude-code.md" v2
C=$(commit "feat(pstack): correct v2")
put "$up/other/README.md" y
H=$(commit "other plugin again") # main moves past the latest pstack change
run check
check "used skill flagged" out_has "Of these, xl-skills uses: correct"
check "added skill" out_has "Skills added: sharpen"
check "harness doc flagged" out_has "claude-code.md changed"

# a skill xl-skills uses renamed upstream shows as removed
saved=$(g rev-parse HEAD)
g mv harness/pstack/claude-code/skills/correct harness/pstack/claude-code/skills/correct-new
g commit -q -m "rename correct"
run check
check "rename: shown as removed" eval 'out_has "Skills removed: correct" && out_has "Of these, xl-skills uses: correct"'
g reset -q --hard "$saved"
rm -rf "$tmp/state/cursor-plugins-full.git" # forget the dropped commit

# the hook: JSON once, then quiet until the interval passes
hook
check "hook: JSON with the bump command" eval 'rc 0 && python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
c=d[\"hookSpecificOutput\"][\"additionalContext\"]
assert d[\"hookSpecificOutput\"][\"hookEventName\"]==\"SessionStart\"
assert \"bump $H\" in c and \"skip $C\" in c and \"feat(pstack): correct v2\" in c and \"pstack update available\" in d[\"systemMessage\"]
" "$tmp/out"'
run check --hook
check "hook: throttled" eval 'rc 0 && out_empty'

# skip: quiet for this change, raised again for a newer one
run skip
check "skip" eval 'rc 0 && [ "$(cat "$tmp/state/skipped")" = "$C" ]'
hook
check "skipped: hook is quiet" eval 'rc 0 && out_empty'
put "$ship/skills/arena/SKILL.md" v3
D=$(commit "chore(pstack): arena v3")
hook
check "newer change: raised again" out_has "chore(pstack): arena v3"

# a failed step puts the previous pin back and re-registers it
cp "$tmp/settings.json" "$tmp/before.json"
: >"$CLAUDE_LOG"
FAIL_ON="plugin marketplace add cursor/plugins#$D" run bump
check "marketplace add fails: pin restored" eval 'rc 1 && same_json "$tmp/settings.json" "$tmp/before.json" && [ "$(cat "$CLAUDE_LOG")" = "plugin marketplace add cursor/plugins#$D
plugin marketplace add cursor/plugins#$A" ]'
: >"$CLAUDE_LOG"
FAIL_ON="plugin update*" run bump
check "plugin update fails: pin restored" eval 'rc 1 && same_json "$tmp/settings.json" "$tmp/before.json" && [ "$(cat "$CLAUDE_LOG")" = "plugin marketplace add cursor/plugins#$D
plugin update pstack@cursor-plugins --scope user
plugin marketplace add cursor/plugins#$A" ]'
: >"$CLAUDE_LOG"
FAIL_ON="plugin*" run bump
check "rollback re-add fails: says so" eval 'rc 1 && grep -q "rollback incomplete" "$tmp/err" && same_json "$tmp/settings.json" "$tmp/before.json"'
: >"$CLAUDE_LOG"

# an update that keeps the old files (same version string) is reinstalled
cp "$tmp/settings.json" "$tmp/before.json"
: >"$CLAUDE_LOG"
STALE=1 run bump "$C"
check "stale update: reinstalled at the pin" eval 'rc 0 && [ "$(cat "$CLAUDE_LOG")" = "plugin marketplace add cursor/plugins#$C
plugin update pstack@cursor-plugins --scope user
plugin uninstall pstack@cursor-plugins --scope user
plugin install pstack@cursor-plugins --scope user" ]'
cp "$tmp/before.json" "$tmp/settings.json"
echo "$A" >"$MKT"
installed "$A"

# same commit recorded but the old files kept: reinstalled
put_stale_files() { python3 - "$tmp/installed.json" <<'EOF2'
import json, sys
d = json.load(open(sys.argv[1]))
print(d["plugins"]["pstack@cursor-plugins"][0]["installPath"])
EOF2
}
run bump "$C"
echo stale >"$(put_stale_files)/skills/correct/SKILL.md"
: >"$CLAUDE_LOG"
STALE=1 run bump "$C"
check "same commit, old files: reinstalled" eval 'rc 0 && grep -q "plugin uninstall" "$CLAUDE_LOG" && [ "$(cat "$(put_stale_files)/skills/correct/SKILL.md")" = v2 ]'
cp "$tmp/before.json" "$tmp/settings.json"
echo "$A" >"$MKT"
installed "$A"

# a rollback keeps settings another session changed meanwhile
: >"$CLAUDE_LOG"
TOUCH=1 FAIL_ON="plugin update*" run bump "$C"
check "rollback keeps unrelated changes" python3 -c "
import json,sys
d=json.load(open(sys.argv[1])); b=json.load(open(sys.argv[2]))
assert d['model']=='sonnet' and d['extraKnownMarketplaces']==b['extraKnownMarketplaces']
" "$tmp/settings.json" "$tmp/before.json"
cp "$tmp/before.json" "$tmp/settings.json"

# bump keeps a private settings file private
chmod 600 "$tmp/settings.json"
run bump "$C"
check "bump keeps the settings file private" eval 'rc 0 && python3 -c "import os,stat,sys; sys.exit(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)!=0o600)" "$tmp/settings.json"'
cp "$tmp/before.json" "$tmp/settings.json"
echo "$A" >"$MKT"
installed "$A"
: >"$CLAUDE_LOG"

# bump: unknown commit leaves settings alone
cp "$tmp/settings.json" "$tmp/before.json"
run bump 0123456789012345678901234567890123456789
check "bump unknown: fails, settings unchanged" eval 'rc 1 && same_json "$tmp/settings.json" "$tmp/before.json"'

# bump to main: pin moves, autoUpdate goes, marketplace re-added, plugin updated
run bump
check "bump: exit 0" rc 0
check "bump: settings pin main" python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
m=d['extraKnownMarketplaces']['cursor-plugins']
assert m['source']['ref']==sys.argv[2] and 'autoUpdate' not in m and d['model']=='opus'
" "$tmp/settings.json" "$D"
check "bump: claude calls" eval '[ "$(cat "$CLAUDE_LOG")" = "plugin marketplace add cursor/plugins#$D
plugin update pstack@cursor-plugins --scope user" ]'
check "bump: skip cleared" eval '[ ! -e "$tmp/state/skipped" ]'
check "bump: reports versions" out_has "${A:0:7} (v0.1.0) -> ${D:0:7} (v0.1.1)"
run check
check "after bump: up to date" rc 0

# bump on a machine without pstack installs it
echo '{"plugins":{}}' >"$tmp/installed.json"
: >"$CLAUDE_LOG"
pin ""
run bump "$B"
check "fresh machine: pinned and installed" eval 'rc 0 && [ "$(cat "$CLAUDE_LOG")" = "plugin marketplace add cursor/plugins#$B
plugin install pstack@cursor-plugins --scope user" ]'
check "fresh machine: settings written" python3 -c "
import json,sys
assert json.load(open(sys.argv[1]))['extraKnownMarketplaces']['cursor-plugins']['source']['ref']==sys.argv[2]
" "$tmp/settings.json" "$B"

# no settings file at all: bump creates it
rm -f "$tmp/settings.json"
run bump "$B"
check "no settings file: created with the pin" eval 'rc 0 && [ "$(PSTACK_PIN_SETTINGS=$tmp/settings.json "$here/pstack-pin.sh" check >/dev/null; echo $?)" = 10 ]'
rm -f "$tmp/settings.json"
echo '{"plugins":{}}' >"$tmp/installed.json"
FAIL_ON="plugin install*" run bump "$B"
check "no settings file, failed: entry removed again" eval 'rc 1 && python3 -c "import json,sys; sys.exit(\"cursor-plugins\" in json.load(open(sys.argv[1])).get(\"extraKnownMarketplaces\", {}))" "$tmp/settings.json" && grep -q "marketplace remove cursor-plugins --scope user" "$CLAUDE_LOG"'

[ "$fails" = 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
