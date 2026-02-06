---
title: Fix imul_imm full immediate lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:34:32.051657+01:00\""
closed-at: "2026-02-06T20:36:43.827036+01:00"
close-reason: Use mov_imm instead of movz truncation in imul_imm non-power-of-two path and add full-immediate regression test
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:4005; cause: imul_imm non-power-of-two path materializes only low 16 bits via movz; fix: use full immediate materialization with mov_imm before mul_rr; deps: none; verification: update/add imul_imm lowering tests for full immediate and run zig build test -j1 --global-cache-dir .zig-global-cache
