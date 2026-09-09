---
name: memory-first-coordination
description: Enforce memory-first task execution, unique session identity, coord ownership, evidence-based status, bounded work, and independent verification. Use for nontrivial project work, resumed tasks, multi-agent Codex/Claude collaboration, status or completion claims, tasks that depend on prior decisions, and any work where duplicate edits or stale memory would be costly.
---

# Memory-First Coordination

Public package version: 0.1.0-draft; adapted from hub skill 0.2.0-draft. Purpose: memory and evidence gates. Acceptance: run the receipt and review-pair checks described in docs/hub-toolkit.md from the repository root.

Treat memory, coordination, execution, and verification as separate gates. Never use a model name such as "Claude" or "Codex" as a session identity.

## 1. Establish identity

Record this tuple before acting:

```text
tool + agent_id + session_id + run_id + process_id + task_id + file_scope
```

Generate a unique `agent_id` per live session. Do not reuse `claude-hub` or `codex-hub` across concurrent sessions.

## 2. Pass the memory gate

Read only task-relevant memory in this order:

1. Central active version and workflow.
2. Project memory and code map, if present.
3. Latest relevant handoff or run receipt.
4. Historical memory registry, only when the task depends on prior decisions.
5. Live files and commands needed to detect drift.

Write a memory receipt containing sources, findings, uncertainties, and live checks. Historical notes are leads, not current truth.

## 3. Pass the coordination gate

For shared work:

1. Check coord health.
2. Send a heartbeat using the unique agent ID.
3. Read current tasks and agents.
4. Claim the task before editing.
5. Record the task ID, lease, role, and exact file scope.
6. Extend the lease before long steps.

If coord is offline, record `offline-fallback` and use a local handoff. Do not pretend a claim exists.

Never send a heartbeat, claim, or completion on behalf of another live session without recording a proxy action and naming the proxy actor.

## 4. Execute within bounds

Use a maximum round count and checkpoints for long work. Stop on scope conflict, failed verification, or an expired claim. Preserve unrelated user changes.

## 5. Use precise status language

Use only these states:

- `working`: the identified session is active.
- `submitted`: the executor produced artifacts and evidence.
- `verified`: an independent reviewer checked the artifacts.
- `closed`: coord or the local ledger records final closure.

Never infer that all Claude or Codex sessions are finished because one process exited or one task closed.

## 6. Pass the completion gate

Before `submitted`, require:

- exact changed-file list;
- actual test commands and exit codes;
- known limitations;
- executor identity.

Before `verified`, require a separate reviewer receipt from a different identity, fresh inspection, and evidence proportional to the claim. Bind it to the executor receipt with task ID, executor ID, and SHA-256. A proxy coord action is not independent proof. Receipt separation does not provide cryptographic identity authentication.

Read [references/receipts.md](references/receipts.md) for receipt fields. Read [references/evidence-rules.md](references/evidence-rules.md) before status or completion reporting.

Use `scripts/new_receipt.ps1` to create receipts, `scripts/validate_receipt.ps1` to validate preflight or submission, and `scripts/validate_review_pair.ps1` to validate independent review.
