---
title: Populate VRegOrigin during constant lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:33:10.258250+01:00\""
closed-at: "2026-01-29T08:40:24.852097+01:00"
---

Record origin when lowering iconst/f32const/f64const.
- File: src/codegen/compile.zig:1719
- When: iconst/f32const/f64const creates vreg
- Store: VRegOrigin{ .opcode = .iconst, .imm = value, .operands = null }
- Map: vreg_origins.put(vreg, origin)
- Depends: hoist-add-vregorigin-struct-e9aaeda4
- Verify: zig build test
