---
title: Add immediate-op lowering tests
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"\\\\\\\"2026-02-06T10:26:38.418745+01:00\\\\\\\"\\\"\""
closed-at: "2026-02-06T10:29:57.509714+01:00"
close-reason: Immediate-op lowering tests already present and passing
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:3750; cause: iadd_imm/irsub_imm/imul_imm lack targeted AArch64 regression checks; fix: add lowering tests asserting add_imm, neg+add_imm, and lsl_imm/movz+mul_rr paths; deps: hoist-backend-parity-cfd28858; verification: zig build test -j1 --global-cache-dir .zig-global-cache
