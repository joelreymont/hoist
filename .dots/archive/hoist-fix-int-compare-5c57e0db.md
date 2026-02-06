---
title: Fix int_compare_imm negative immediates
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:26:35.406037+01:00\""
closed-at: "2026-02-06T20:28:39.170955+01:00"
close-reason: Restrict cmp_imm path to non-negative immediates and add negative-immediate regression coverage
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:5556; cause: int_compare_imm checks only imm<=4095 so negative immediates incorrectly take cmp_imm path (unsigned-only) and can mis-lower/trap on cast; fix: require imm>=0 for cmp_imm and use mov_imm+cmp_rr for negative immediates; deps: none; verification: add i32/i64 negative-immediate lowering regression test and run zig build test -j1 --global-cache-dir .zig-global-cache
