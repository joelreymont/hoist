---
title: Implement getDefs/getUses for all Inst variants
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:48:48.705174+02:00"
closed-at: "2026-01-06T23:02:29.852973+02:00"
---

File: src/backends/aarch64/inst.zig - Add getDefs() and getUses() methods to Inst enum (250 variants). Each variant must extract VRegs from dst (defs) and src (uses) fields. This is blocked by scale - consider alternative approach: 1) Reuse regalloc_bridge extraction logic, 2) Generate methods from instruction definitions, 3) Use macro/comptime generation. Priority: Low until we need LinearScan for performance.
