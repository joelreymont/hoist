---
title: Implement i128 ctz lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:50:15.703500+01:00\""
closed-at: "2026-02-06T23:54:01.332193+01:00"
close-reason: Wired ISLE ctz i128 to helper and added helper coverage
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:1732 and /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig i128 helpers; cause: ctz i128 currently lowers to aarch64_unimplemented; fix: add lower_ctz128 helper (rbit+clz with low-half zero select) and wire ISLE rule; deps: hoist-implement-i128-bit-732100ae; verification: add helper-level test and run zig build test -j1 --global-cache-dir .zig-global-cache
