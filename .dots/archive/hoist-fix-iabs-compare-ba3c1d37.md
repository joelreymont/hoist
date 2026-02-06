---
title: Fix iabs compare width
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:05:55.444942+01:00\""
closed-at: "2026-02-06T20:08:45.564719+01:00"
close-reason: Use iabs operand width for cmp_imm and cover i32/i64 with lowering test
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:4758; cause: iabs lowering emits cmp_imm with hardcoded size64, which is incorrect for I32; fix: use operand size derived from value type; deps: none; verification: add lowering regression test for i32/i64 cmp_imm size and run zig build test -j1 --global-cache-dir .zig-global-cache
