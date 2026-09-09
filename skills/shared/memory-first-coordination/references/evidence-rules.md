# Evidence rules

## Evidence strength

- A: command actually ran and its exit code/output was inspected.
- B: current file was read directly.
- C: another identified agent supplied evidence that has not been independently repeated.
- D: inference, plan, or historical memory.

Match claim strength to evidence strength. Do not use C or D alone for a broad completion claim.

## Status boundaries

- A process exit proves only that process ended.
- A file timestamp proves only that a file changed.
- A passing narrow test proves only what that test covers.
- A coord task marked complete proves ledger state, not that all related sessions stopped.
- A controller-issued proxy heartbeat proves controller activity, not executor activity.

## Reviewer checklist

1. Bind the claim to one identity tuple.
2. Inspect the declared scope and changed files.
3. Re-run the relevant tests when safe.
4. Check for active sessions before making global status statements.
5. Record contradictions and stale documentation.
6. Use `verified` only after independent evidence.
