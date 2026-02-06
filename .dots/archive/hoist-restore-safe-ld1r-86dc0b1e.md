---
title: Restore safe LD1R splat-load fusion
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:29:22.185733+01:00\""
closed-at: "2026-02-06T19:41:58.755362+01:00"
close-reason: Implemented LD1R fusion in aarch64_splat with regression test
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:900 and /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig. Cause: direct splat(load) rule matcher can unwrap null on non-splat vectors; fusion was disabled. Fix: add dedicated extractor for splat(load addr, offset=0) and re-enable LD1R rule through guarded extractor. Add regression test in /Users/joel/Work/hoist/src/backends/aarch64/lower_test.zig. Dependencies: hoist-lower-avg-round-c8af487b. Verification: zig build test -j1 --global-cache-dir .zig-global-cache.
