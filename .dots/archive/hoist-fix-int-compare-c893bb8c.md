---
title: Fix int_compare_imm large immediate
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:21:10.782551+01:00\""
closed-at: "2026-02-06T20:24:44.908554+01:00"
close-reason: Use mov_imm for full immediate materialization and add large-imm lowering regression test
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:5585; cause: int_compare_imm with imm>4095 materializes only low16 via movz causing wrong compares; fix: materialize full immediate via mov_imm (or MOVZ/MOVK sequence) then cmp_rr; deps: none; verification: add lowering regression test for i32/i64 large immediates and run zig build test -j1 --global-cache-dir .zig-global-cache
