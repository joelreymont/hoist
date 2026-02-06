---
title: Implement avg_round I64X2 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:44:02.841676+01:00\""
closed-at: "2026-02-06T19:48:58.104246+01:00"
close-reason: Implemented I64X2 avg_round lowering with tests
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:613 and /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig. Cause: I64X2 avg_round still lowers to aarch64_unimplemented. Fix: add helper that computes ((x>>1)+(y>>1))+((x|y)&1) using vector shifts/add/or and wire rule. Add regression test in /Users/joel/Work/hoist/src/backends/aarch64/lower_test.zig. Dependencies: PLAN.md parity section 8. Verification: zig build test -j1 --global-cache-dir .zig-global-cache.
