---
title: Fix int_compare_imm width
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:09:05.632491+01:00\""
closed-at: "2026-02-06T20:11:44.100624+01:00"
close-reason: Use operand width for cmp_imm in int_compare_imm path and add i32/i64 regression tests
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:5570; cause: int_compare_imm with imm<=4095 emits cmp_imm size64 even for I32 operands; fix: use operand-derived size; deps: none; verification: add lowering regression test for i32/i64 int_compare_imm cmp size and run zig build test -j1 --global-cache-dir .zig-global-cache
