---
title: Test unsupported reg classes
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T09:36:10.773971+01:00\""
closed-at: "2026-02-07T09:38:20.110303+01:00"
close-reason: completed
---

Context: /Users/joel/Work/hoist/src/machinst/regalloc.zig now returns error.UnsupportedRegClass for scalable_vector/predicate in allocate/free, but lacks explicit regression tests. Cause: behavior can regress silently in simple allocator path. Fix: add unit tests that assert unsupported classes are rejected for allocation and deallocation paths. Verification: zig build test -j1 --global-cache-dir .zig-global-cache.
