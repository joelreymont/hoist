---
title: Wire I128 shift lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:55:34.654256+01:00\""
closed-at: "2026-02-07T00:10:11.898134+01:00"
close-reason: Routed i128 shift rules, fixed two-csel constructor shape, and added lowering regressions
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:1049-1165 still routes I128 ishl/ushr/sshr to aarch64_unimplemented despite existing lower_shl128/lower_ushr128/lower_sshr128 rules. Cause: missing rule wiring to helper path. Fix: replace unimplemented rules with emit_regs(lower_*128 (put_in_regs x) (put_in_reg y)) and add lowering tests to ensure no unimplemented for I128 shifts. Dependencies: hoist-implement-i128-ctz-422f08f4. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures.
