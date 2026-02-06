---
title: Fix AArch64 float select lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T00:12:05.486404+01:00\""
closed-at: "2026-02-07T00:20:37.972166+01:00"
close-reason: Updated fpu_csel to fcsel and added helper-level coverage for consumes-flags payload
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig:5178 fpu_csel still uses removed Inst.FpuCSel shape. Cause: stale constructor API drift leaves float select path untested and broken. Fix: migrate fpu_csel to Inst.fcsel + current operand/size types and add lower_test that lowers F64 select and expects fcsel. Dependencies: hoist-wire-i128-shift-09bd57a1. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures.
