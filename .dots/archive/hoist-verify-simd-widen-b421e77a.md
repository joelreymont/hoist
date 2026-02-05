---
title: Verify SIMD widen-load lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T20:51:20.169531+01:00\""
closed-at: "2026-02-05T20:52:03.709461+01:00"
close-reason: Added u/sload widening coverage tests for 8x8,16x4,32x2 paths
---

Context: src/backends/aarch64/lower.isle:1878-1912; cause: need explicit coverage for uload8x8/sload8x8/uload16x4/sload16x4/uload32x2/sload32x2; fix: add ISLE coverage tests asserting corresponding aarch64_* constructors fire; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache
