# Session receipt

Keep one JSON receipt per run. The receipt is a compact audit record, not a transcript.

## Required structure

```json
{
  "schema_version": 2,
  "identity": {
    "tool": "claude",
    "agent_id": "claude-vscode-a1b2c3d4",
    "session_id": "a1b2c3d4",
    "run_id": "20260707-claude-a1b2c3d4",
    "process_id": 1234
  },
  "task": {
    "task_id": "coord-id-or-local-id",
    "goal": "specific outcome",
    "role": "executor",
    "scope": ["allowed/path/**"]
  },
  "memory": {
    "sources": ["AI_WORKFLOW.md"],
    "findings": ["one relevant prior decision"],
    "uncertainties": ["fact requiring live verification"]
  },
  "coordination": {
    "state": "claimed",
    "evidence": "task id and lease",
    "proxy_actions": []
  },
  "live_checks": ["command or file evidence"],
  "execution": {
    "max_rounds": 6,
    "current_round": 0,
    "status": "working",
    "changed_files": [
      {"path": "relative/file.md", "action": "added|modified|deleted"}
    ],
    "tests": [
      {
        "command": "exact command",
        "exit_code": 0,
        "observed_at": "2026-07-07T09:00:00+08:00",
        "evidence": "short output summary"
      }
    ]
  },
  "review": {
    "reviewer_id": null,
    "subject_executor_id": null,
    "subject_receipt_path": null,
    "subject_receipt_sha256": null,
    "evidence": [],
    "status": "not_started"
  }
}
```

## Rules

- Keep secrets and full prompts out of receipts.
- Use forward-slash paths in JSON when convenient.
- Add proxy actions as `{ "actor": "...", "action": "...", "reason": "..." }`.
- Set executor status to `submitted`, never directly to `verified`.
- Keep executor and reviewer evidence in separate receipts.
- Let a different identity create the reviewer receipt and set its review status to `verified`.
- Use `validate_review_pair.ps1` to bind both receipts by task ID, executor ID, and SHA-256.
- Receipt separation is structural evidence, not cryptographic identity authentication; record that limitation when stronger guarantees matter.
