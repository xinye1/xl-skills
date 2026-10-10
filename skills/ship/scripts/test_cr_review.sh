#!/usr/bin/env bash
# Tests for cr_review.sh against a fake coderabbit; no real reviews are used.
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

# The fake CLI: rate-limits the first $LIMITED calls, then completes (or fails
# with exit 7 when FAIL=1). It logs each call's start and end.
mkdir "$tmp/bin"
cat >"$tmp/bin/coderabbit" <<'FAKE'
#!/usr/bin/env bash
n=$(( $(cat "$STATE" 2>/dev/null || echo 0) + 1 ))
echo $n >"$STATE"
echo "start $$ $(date +%s.%N)" >>"$LOG"
trap 'kill "$nap" 2>/dev/null; exit 143' TERM # a timed-out run leaves no sleep behind
sleep "${HOLD:-0}" &
nap=$!
wait "$nap"
echo "end $$ $(date +%s.%N)" >>"$LOG"
if [ "${FAIL:-0}" = 1 ]; then echo "Error: something else"; exit 7; fi
if [ "${CRASH:-0}" = 1 ]; then printf 'Review complete\nSegmentation fault\n'; exit 139; fi
if [ "$n" -le "${LIMITED:-0}" ]; then
	printf '  \033[31m✗ Review limit reached\033[0m\n  You can wait 0 minutes and 1 seconds for the limit to reset.\nError: Rate limit exceeded\n'
	exit 1
fi
printf 'Compare   : feat → origin/main\nReview complete\nNo findings ✔\n'
FAKE
chmod +x "$tmp/bin/coderabbit"
export PATH="$tmp/bin:$PATH" CR_WAIT_MARGIN_SEC=0 CR_LOCK_FILE="$tmp/lock" LOG="$tmp/log"

# completes after two rate-limited attempts, sleeping the reported wait
STATE="$tmp/s1" LIMITED=2 "$here/cr_review.sh" "$tmp/out1" >"$tmp/o1"
rc=$?
check "exit 0 once the review completes" [ $rc = 0 ]
check "retried past two rate limits" [ "$(cat "$tmp/s1")" = 3 ]
check "reports the trailer" grep -q 'Review complete' "$tmp/o1"
check "keeps the full output" grep -q 'No findings' "$tmp/out1"

# another CLI failure is not retried
STATE="$tmp/s2" FAIL=1 "$here/cr_review.sh" "$tmp/out2" >/dev/null 2>"$tmp/e2"
rc=$?
check "exit 1 on another CLI failure" [ $rc = 1 ]
check "no retry on another failure" [ "$(cat "$tmp/s2")" = 1 ]

# a trailer from a run that then failed is not success
STATE="$tmp/s5" CRASH=1 "$here/cr_review.sh" "$tmp/out5" >/dev/null 2>&1
rc=$?
check "exit 1 when the CLI fails after printing a trailer" [ $rc = 1 ]

# a failed fetch of the base stops before reviewing
git init -q "$tmp/repo" && git -C "$tmp/repo" remote add origin "$tmp/no-such-remote"
(cd "$tmp/repo" && STATE="$tmp/s6" "$here/cr_review.sh" "$tmp/out6" --base origin/main) >/dev/null 2>&1
rc=$?
check "exit 1 when the base can't be fetched" [ $rc = 1 ]
check "no review of a stale base" [ ! -e "$tmp/s6" ]

# gives up when the wait would pass the cap
STATE="$tmp/s3" LIMITED=99 CR_MAX_WAIT_SEC=2 CR_WAIT_MARGIN_SEC=5 "$here/cr_review.sh" "$tmp/out3" >/dev/null 2>&1
rc=$?
check "exit 3 when giving up" [ $rc = 3 ]

# two sessions at once queue on the lock instead of overlapping
: >"$LOG"
STATE="$tmp/s4" HOLD=1 "$here/cr_review.sh" "$tmp/out4a" >"$tmp/o4a" &
until grep -q '^start' "$LOG"; do sleep 0.05; done # the first holds the lock now
STATE="$tmp/s4" HOLD=1 "$here/cr_review.sh" "$tmp/out4b" >"$tmp/o4b" &
wait
check "the second session says it is queued" grep -q queued "$tmp/o4b"
overlap=$(awk '/^start/ { if (open) bad = 1; open = 1 } /^end/ { open = 0 } END { print bad + 0 }' \
	<(sort -k3 -n "$LOG"))
check "reviews never overlap" [ "$overlap" = 0 ]

# time queued for the lock counts against the wait budget
flock "$CR_LOCK_FILE" sleep 5.17 &
holder=$!
sleep 0.3
t0=$SECONDS
STATE="$tmp/s8" CR_MAX_WAIT_SEC=1 "$here/cr_review.sh" "$tmp/out8" >/dev/null 2>&1
rc=$?
check "exit 3 when queued past the budget" [ $rc = 3 ]
check "and gives up within the budget" [ $((SECONDS - t0)) -le 3 ]
check "without running a review" [ ! -e "$tmp/s8" ]
pkill -P "$holder" 2>/dev/null
kill "$holder" 2>/dev/null
wait "$holder" 2>/dev/null

# a hung review run is cut off
STATE="$tmp/s9" HOLD=5.13 CR_REVIEW_TIMEOUT_SEC=1 "$here/cr_review.sh" "$tmp/out9" >/dev/null 2>&1
rc=$?
check "exit 1 when a review run hangs" [ $rc = 1 ]

# the base is refreshed even in a clone that maps only its own branch
git init -q --bare -b main "$tmp/remote.git"
git clone -q "$tmp/remote.git" "$tmp/seed" 2>/dev/null
git -C "$tmp/seed" -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
git -C "$tmp/seed" push -q origin HEAD:main HEAD:feature
git clone -q --single-branch --branch feature "$tmp/remote.git" "$tmp/narrow"
git -C "$tmp/seed" -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
git -C "$tmp/seed" push -q origin HEAD:main
(cd "$tmp/narrow" && STATE="$tmp/s10" "$here/cr_review.sh" "$tmp/out10" --base origin/main) >/dev/null 2>&1
check "origin/main is updated before the review" \
	[ "$(git -C "$tmp/narrow" rev-parse -q --verify origin/main)" = "$(git -C "$tmp/remote.git" rev-parse main)" ]

# killing a wrapper that is waiting out a rate limit frees the lock at once
STATE="$tmp/s7" LIMITED=99 CR_WAIT_MARGIN_SEC=60 "$here/cr_review.sh" "$tmp/out7" >/dev/null 2>&1 &
victim=$!
sleep 0.5
kill "$victim"
wait "$victim" 2>/dev/null
sleep 0.2
check "a killed wrapper releases the lock" flock -n "$CR_LOCK_FILE" true
check "and leaves no sleep behind" bash -c '! pgrep -f "^sleep 61$" >/dev/null'

# usage
"$here/cr_review.sh" >/dev/null 2>&1
check "exit 2 without an output file" [ $? = 2 ]

echo
[ $fails = 0 ] && echo "all passed" || echo "$fails failed"
exit $((fails != 0))
