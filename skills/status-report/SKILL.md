---
name: status-report
description: Use when the user asks "status report", "status update", "where are we", "what's the progress", "is it done?", "has it landed?", "progress update", "ping", or "check in" while long-running work (background jobs, training runs, backfills, CI, deploys, subagents) is in flight — and proactively whenever launching work that will outlive the next few exchanges, or when the user says "let it run", "report progress every hour", or "last update before I sleep". Also use when progress tracking has failed before (completed jobs went unnoticed, monitors died with the session) and the supervision setup itself needs fixing.
---

# Status report — supervise long-running work and report it honestly

This skill has two halves that only work together: **the report** (what to say when the user asks "where are we") and **the supervision rig** (what to set up when launching long work so that the report is answerable from evidence, not memory). Most bad status reports were lost at launch time, not at asking time.

## The report format

Every status report, whether asked-for or scheduled:

1. **Timestamp first.** Local time of *this* check, not of the last known event. Scheduled reports without timestamps are useless in a scrollback.
2. **Per-workstream line:** state (`running` / `done` / `failed` / `stalled` / `waiting-on-user`), progress against expectation (e.g. "cell 14/24, was 9/24 an hour ago"), and ETA if inferable. "Still running" with no delta is not a status — it's an admission you didn't look.
3. **What changed since the last report.** The delta is the content; repeat nothing the user already confirmed reading.
4. **Blockers and needs-you items** called out explicitly, at the top if any exist.
5. **Next checkpoint:** when the user will hear from you again and what will have happened by then.

Keep it terse (per the user's concision preference) — a 6-line report that is all signal beats a structured page.

## Evidence, not recollection

Before reporting, **check the live state**: sentinel/exit files, `pgrep` for worker liveness, log tails with timestamps, background-task output, `gh run view --json jobs` for CI (not the watch tail — it false-alarms on skipped steps), container status for deploys. Never report from what *should* be happening. If a signal is missing, say "unknown — checking" and go check; an honest "not captured" beats a plausible guess.

## The supervision rig — set up at launch, not at panic

When launching anything that outlives a few exchanges:

- **Make completion observable:** run via the harness's background tasks (you get notified on exit) *and* leave a filesystem sentinel (e.g. `job.exit` with the exit code, timestamped log). The sentinel survives session teardown; the notification doesn't.
- **Cadence:** if the user asked for periodic reports ("hourly"), schedule them (wakeup/monitor) rather than promising to remember. Each firing produces the full report format above.
- **Re-arm after disruption.** After a restart, resume, or context handover, first verify the monitors are still armed; if the session that owned them is gone, re-arm before doing anything else.
- **Overnight / away mode** ("last status update before I go to sleep"): the report additionally states what will run unattended, how failure will surface to the user (e.g. ntfy push), and what you will have checked by morning.
- **Failure is a first-class outcome:** a job that died should surface as loudly as one that finished. Check exit codes, not just presence of output.

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| Reporting remembered state instead of checking | The one time it diverges (job OOM-killed, VM rebooted) the report is fiction. |
| "Still running" with no progress delta or ETA | Forces the user to keep asking; the whole point is they shouldn't have to. |
| Completion discovered only when the user asks "is it done?" | Supervision failed at launch — no sentinel, no background-task tracking, no re-armed monitor. |
| Scheduled reports without timestamps | Indistinguishable in scrollback; the user explicitly wants timestamps. |
| Polling in a tight loop | Wasteful; match check frequency to how fast the state can actually change. |
| Burying a needs-you blocker mid-report | Blockers go first; everything else is context. |

## When NOT to use

- Short tasks that finish within the exchange — just do them and report the outcome.
- The user asks a *specific* question ("which 2 tests failed?") — answer it directly; don't wrap it in the full format.
