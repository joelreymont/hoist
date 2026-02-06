---
title: Lower avg_round vector opcode
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:19:15.007277+01:00\""
closed-at: "2026-02-06T19:27:59.302967+01:00"
close-reason: Lowered avg_round to URHADD and added test
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:605 and /Users/joel/Work/hoist/src/backends/aarch64/lower_test.zig; cause: avg_round for lane_fits_in_32 still lowers to aarch64_unimplemented; fix: lower to VecALUOp.Urhadd and add lowering regression test; deps: PLAN.md section 5 parity; verification: zig build test -j1 --global-cache-dir .zig-global-cache
