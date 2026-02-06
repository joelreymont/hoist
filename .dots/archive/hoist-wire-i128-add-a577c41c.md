---
title: Wire I128 add/sub pair lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T00:13:17.942736+01:00\""
closed-at: "2026-02-07T00:17:37.368537+01:00"
close-reason: Added ADDS+ADCS and SUBS+SBCS helpers with I128 rule wiring and helper regressions
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:452-471 still maps iadd/isub I128 to aarch64_unimplemented. Cause: missing pair arithmetic lowering despite available ADDS/ADCS/SUBS/SBCS instructions. Fix: add lower_iadd128/lower_isub128 helpers in /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig, wire lower.isle rules to emit_regs helpers, and add helper tests for instruction sequences. Dependencies: hoist-wire-i128-shift-09bd57a1. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures.
