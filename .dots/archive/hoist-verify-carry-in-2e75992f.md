---
title: Verify carry-in and borrow-in overflow lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-05T20:52:26.637200+01:00\\\"\""
closed-at: "2026-02-05T21:11:27.316769+01:00"
close-reason: Add carry/borrow-in lowering coverage tests
---

Context: src/backends/aarch64/lower.isle:3281-3301; cause: need explicit coverage for uadd_overflow_cin/sadd_overflow_cin/usub_overflow_bin/ssub_overflow_bin; fix: add ISLE coverage tests asserting adcs/sbcs constructors are exercised; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
