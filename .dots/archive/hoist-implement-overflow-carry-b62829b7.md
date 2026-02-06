---
title: Implement overflow carry-in lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:40:32.130596+01:00\""
closed-at: "2026-02-06T23:43:08.171775+01:00"
close-reason: Added uadd/sadd overflow-with-carry helpers and tests for CMP+ADCS+CSET lowering sequence
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:3384 and /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig overflow section; cause: aarch64_uadd_overflow_cin/aarch64_sadd_overflow_cin declared in ISLE but missing helper implementations; fix: add helpers using CMP+ADCS+CSET and add unit tests for emitted instruction sequence; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
