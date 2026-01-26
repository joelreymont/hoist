---
title: Implement struct return classification
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:09:58.441192+01:00\""
closed-at: "2026-01-26T11:26:33.449163+01:00"
---

File: src/backends/aarch64/abi.zig:3735
Replace TODO at line 3735 with proper classification:
- Call ty.getStructFields(store)
- Check <=16 bytes: X0 or X0+X1
- Check HFA: V0-V3
- Else: indirect via X8
Deps: hoist-wire-structstore-into-3fb37168
Verify: zig build test -Dtest-filter=classifyReturn
