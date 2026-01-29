---
title: Add VRegOrigin struct for rematerialization
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:33:03.916394+01:00\""
closed-at: "2026-01-29T08:38:10.999464+01:00"
---

Add struct to track IR origin of vregs.
- File: src/codegen/compile.zig:1400
- Add: VRegOrigin = struct { opcode: Opcode, imm: ?i64, operands: [2]?VReg }
- Purpose: Track what IR instruction produced each vreg for later rematerialization
- Verify: zig build
