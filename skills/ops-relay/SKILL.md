---
name: ops-relay
description: Use when driving hands-on work through the user on a machine or device Claude cannot reach directly — provisioning a fresh VPS, SSH/deploy-key/tailnet setup, running migrations on a remote host, pairing a phone over adb wireless debugging, fixing the Windows/WSL host, clicking through a cloud-provider console — recognisable by the user pasting terminal output or console screenshots and asking "what do I do next", "what have I missed", "I ran it and got this", or by any runbook that must be executed on hardware only the user can touch.
---

# Ops relay — driving remote hands, one verified step at a time

In this mode the user's hands and eyes are the only actuator: they run what you give them and paste back what they see. The failure modes are all coordination failures — batching steps that fail midway, losing track of which machine a command targets, assuming success without evidence. The discipline:

## The loop

1. **One step, one block.** A single copy-pasteable command block (or one console action), doing one logical thing. No 10-step scripts: when step 3 fails mid-batch, the state is unknown and the user is stranded (SSH host-key prompts, permission errors, and missing keys *will* interrupt batches).
2. **Say what success looks like** before they run it — the expected output, the line that matters, or "no output = good". The user shouldn't have to guess whether to proceed.
3. **Wait for the paste.** Read *all* of it, not just the last line — partial successes and warnings hide mid-output. If the paste is truncated or missing the part you need, ask for that specific output; never guess.
4. **Adapt or advance.** On failure, diagnose from the evidence and issue a corrected step (never re-issue the same failed command unchanged); on success, tick the ledger and move on.

## Session discipline

- **Label the host.** In mixed-host sessions (local WSL vs VPS vs phone vs Windows), prefix every block with where it runs (`# on the VPS`, `# local WSL`). Wrong-host execution is a silent killer.
- **Keep a step ledger** — done / current / remaining — so "where are we" has an instant answer, and so a handover mid-relay is possible.
- **Prefer verification built into the step**: append the check to the command block (`... && systemctl status x --no-pager | head -3`) so one paste both acts and proves.
- **Idempotence where cheap:** write steps that are safe to re-run (`mkdir -p`, `--force-recreate`, guarded appends), because re-runs happen.
- **Secrets stay with the user:** have them paste secrets at an interactive prompt or into a file themselves; never ask them to inline a secret into a command that lands in shell history or the chat.
- **Screenshots are evidence too:** when the interface is a web console or phone, ask for a screenshot at the same checkpoints you'd ask for terminal output.

## Closure — the relay is a test of the runbook

When the goal is reached, immediately write the *proven* path back into the runbook/docs: the actual commands that worked, the real prices/ports/hostnames encountered, the gotchas that interrupted the happy path (host-key prompt, deploy-key config, firewall rule). A runbook that predates the relay is a hypothesis; the relay run is the evidence. If no runbook exists and the task will recur, create one (or a project skill).

## Anti-patterns

| Anti-pattern | Why it hurts |
|---|---|
| Multi-step batch dumps | One mid-batch failure leaves unknown state and a stranded user. |
| Assuming success without the paste | "Should have worked" isn't evidence; the next steps compound the error. |
| Reading only the last line of a paste | Warnings and partial failures live mid-output. |
| Losing track of which host | Commands run on the wrong machine corrupt the *good* environment. |
| Re-issuing the identical failed command | It will fail identically; diagnose first. |
| Finishing without updating the runbook | The next provisioning re-discovers every gotcha from scratch. |

## When NOT to use

- You have direct access (SSH over the tailnet works, adb is connected) — just run it yourself and report; only relay the parts genuinely gated on the user (approvals, physical actions, secrets, console clicks).
- Pure Q&A about a remote system with nothing to execute.
