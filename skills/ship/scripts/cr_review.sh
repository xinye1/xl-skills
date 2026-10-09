#!/usr/bin/env bash
# Run a CodeRabbit CLI review without racing other sessions for the quota.
#
#   cr_review.sh OUT_FILE [coderabbit review args...]
#   e.g. cr_review.sh /tmp/cr.txt --base origin/main --committed
#
# Every Claude session on this machine shares one CodeRabbit bucket, and the
# GitHub app draws on it too. Sessions that each retry on a timer keep using
# attempts up and pushing everyone's wait out. This wrapper:
#   - takes a machine-wide lock, so sessions queue instead of all polling;
#   - when the CLI is rate-limited, sleeps for the wait it reports (plus a
#     margin) while holding the lock, then retries;
#   - re-fetches the base before each attempt (--base origin/<branch>), so a
#     long wait doesn't end in a review of a stale diff;
#   - fails loud: exits 0 only when the run's own trailer says the review
#     completed. The last run's full output is in OUT_FILE either way.
#
# Exit codes: 0 review completed (read OUT_FILE for the findings),
#             1 the CLI failed for another reason, 2 usage,
#             3 gave up after CR_MAX_WAIT_SEC (default 3 hours).
set -u

if [ $# -lt 1 ]; then
	echo "usage: cr_review.sh OUT_FILE [coderabbit review args...]" >&2
	exit 2
fi
out=$1
shift
max_wait=${CR_MAX_WAIT_SEC:-10800}
margin=${CR_WAIT_MARGIN_SEC:-30}
lock=${CR_LOCK_FILE:-${XDG_RUNTIME_DIR:-/tmp}/coderabbit-review.lock}

# the remote base to refresh, from --base origin/<branch> or --base=origin/<branch>
base=
prev=
for a in "$@"; do
	case "$a" in --base=origin/*) base=${a#--base=origin/} ;; esac
	[ "$prev" = --base ] && case "$a" in origin/*) base=${a#origin/} ;; esac
	prev=$a
done

exec 9>"$lock"
if ! flock -n 9; then
	echo "cr_review: queued behind another session's review"
	flock 9
fi

start=$SECONDS
attempt=0
while :; do
	attempt=$((attempt + 1))
	[ -n "$base" ] && git fetch -q origin "$base"
	coderabbit review "$@" >"$out" 2>&1
	rc=$?
	if grep -qE 'Review complete' "$out"; then
		echo "cr_review: attempt $attempt completed"
		grep -E 'Compare|Review complete|findings' "$out" | sed 's/\x1b\[[0-9;]*m//g'
		exit 0
	fi
	if ! grep -qiE 'rate limit|review limit' "$out"; then
		echo "cr_review: the CLI failed (exit $rc); see $out" >&2
		tail -5 "$out" >&2
		exit 1
	fi
	wait=$(grep -oE 'wait [0-9]+ minutes? and [0-9]+ seconds?' "$out" | head -1 |
		awk '{ print $2 * 60 + $5 }')
	wait=$((${wait:-300} + margin))
	if [ $((SECONDS - start + wait)) -gt "$max_wait" ]; then
		echo "cr_review: still rate-limited after $((SECONDS - start)) s; giving up" >&2
		exit 3
	fi
	echo "cr_review: attempt $attempt rate-limited; retrying in $wait s"
	sleep "$wait"
done
