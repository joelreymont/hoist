---
title: Add isCheapToRematerialize helper
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T08:33:28.185175+01:00\""
closed-at: "2026-01-29T08:42:22.306894+01:00"
---

Predicate for rematerializable opcodes.
- File: src/codegen/compile.zig (near line 580)
- Add: fn isCheapToRematerialize(opcode: Opcode) bool
- Return true for: iconst, f32const, f64const, iadd, isub, band, bor, bxor
- Verify: zig build test
