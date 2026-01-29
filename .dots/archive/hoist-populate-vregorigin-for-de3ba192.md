---
title: Populate VRegOrigin for cheap binary ops
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:33:16.334382+01:00\""
closed-at: "2026-01-29T08:41:42.527025+01:00"
---

Record origin for iadd/isub/band/bor/bxor.
- File: src/codegen/compile.zig:1824-1827
- When: binary op creates result vreg
- Store: VRegOrigin{ .opcode = op, .imm = null, .operands = .{lhs_vreg, rhs_vreg} }
- Depends: hoist-add-vregorigin-struct-e9aaeda4
- Verify: zig build test
