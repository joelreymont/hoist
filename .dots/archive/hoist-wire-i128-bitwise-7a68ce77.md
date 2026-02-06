---
title: Wire I128 bitwise pair lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T00:20:46.891965+01:00\""
closed-at: "2026-02-07T00:23:42.605510+01:00"
close-reason: Wired band/bor/bxor/bnot I128 rules to pair helpers and added helper regressions
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:1378-1648 leaves I128 band/bor/bxor/bnot as aarch64_unimplemented. Cause: missing pair-lane lowering despite scalar and/or/eor/mvn constructors. Fix: add lower_band128/lower_bor128/lower_bxor128/lower_bnot128 helpers in /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig, wire ISLE rules via emit_regs, and add helper tests asserting and_rr/orr_rr/eor_rr/mvn emission. Dependencies: hoist-wire-i128-add-a577c41c. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures.
