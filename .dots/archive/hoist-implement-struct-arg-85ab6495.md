---
title: Implement struct arg classification in abi.zig
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:09:52.627848+01:00\""
closed-at: "2026-01-26T11:26:33.441608+01:00"
---

File: src/backends/aarch64/abi.zig:1572
Replace TODO at line 1572 with proper classification:
- Call ty.getStructFields(store)
- Use existing isHFA/isHVA with real fields
- Route to HFA/HVA/GPR/stack based on result
Deps: hoist-wire-structstore-into-3fb37168
Verify: zig build test -Dtest-filter=abi
