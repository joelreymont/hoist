---
title: Add block-level spill tracking struct
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:33:42.097484+01:00\""
closed-at: "2026-01-29T08:59:16.544123+01:00"
---

Track which vregs are spilled per block for reload hoisting.
- File: src/codegen/compile.zig:594
- Add: BlockSpillInfo = struct { spilled_vregs: AutoHashMap(VReg, void), reloaded: AutoHashMap(VReg, PReg) }
- Purpose: Know which vregs need reload at block entry
- Verify: zig build
