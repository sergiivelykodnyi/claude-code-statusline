---
schema_version: 1
open_count: 2
waived_count: 0
fixed_count: 0
total_count: 2
last_updated: 2026-09-12T21:22:45.101Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | quick-260912-vgx | unrun-verify | tests/sandbox.sh |  | Sandbox parity run not executed on host: §5.13 Fable shape and the new §5.14 folded date '+%s %z' GNU-userland probe are unverified | open |  | 2026-09-12T20:23:12.892Z |  |
| 2 | quick-260912-x11 | unrun-verify | tests/sandbox.sh |  | Sandbox parity run still not executed (docker info fails on this host): the re-pinned §5.13 Fable arms and the now-counted §5.14 folded date check are unverified in-container, and the container's zone database is unknown — the four new 'zone database present' rows may go red there | open |  | 2026-09-12T21:22:45.101Z |  |

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
  },
  {
    "id": 2,
    "kind": "unrun-verify",
    "phase": "quick-260912-x11",
    "file": "tests/sandbox.sh",
    "line": null,
    "description": "Sandbox parity run still not executed (docker info fails on this host): the re-pinned §5.13 Fable arms and the now-counted §5.14 folded date check are unverified in-container, and the container's zone database is unknown — the four new 'zone database present' rows may go red there",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T21:22:45.101Z",
    "resolved_at": null
  }
]
````
