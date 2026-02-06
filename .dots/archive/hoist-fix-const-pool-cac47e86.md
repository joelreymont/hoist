---
title: Fix constant pool dedupe keying
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:03:33.646097+01:00\""
closed-at: "2026-02-06T23:05:55.586273+01:00"
close-reason: Avoid f32/f64 constant aliasing in pool dedup map
---

Context: /Users/joel/Work/hoist/src/machinst/buffer.zig:253,474; cause: const_pool_map keys only by value and can alias f32/f64 constants with same bits; fix: key dedupe by {value,size} and add regression tests for same-value different-size constants; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
