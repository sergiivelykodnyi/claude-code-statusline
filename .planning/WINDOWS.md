---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-09-12T20:23:12.892Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | quick-260912-vgx | unrun-verify | tests/sandbox.sh |  | Sandbox parity run not executed on host: §5.13 Fable shape and the new §5.14 folded date '+%s %z' GNU-userland probe are unverified | open |  | 2026-09-12T20:23:12.892Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "quick-260912-vgx",
    "file": "tests/sandbox.sh",
    "line": null,
    "description": "Sandbox parity run not executed on host: §5.13 Fable shape and the new §5.14 folded date '+%s %z' GNU-userland probe are unverified",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T20:23:12.892Z",
    "resolved_at": null
  }
]
````
