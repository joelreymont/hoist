---
title: Fix regalloc fuzz drift
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T09:34:22.714132+01:00\""
closed-at: "2026-02-07T09:34:25.118582+01:00"
close-reason: completed
---

Context: /Users/joel/Work/hoist/fuzz/fuzz_regalloc.zig:1 and /Users/joel/Work/hoist/src/machinst/regalloc.zig:70. Cause: fuzzer used stale APIs and failed to compile with Zig 0.15 and current LinearScanAllocator; free/allocate switch did not handle full RegClass enum. Fix: rewrite fuzzer to random allocate/free invariant checks on current allocator API; add explicit UnsupportedRegClass handling in allocator for scalable_vector/predicate. Verification: zig build fuzz; zig build test -j1 --global-cache-dir .zig-global-cache.
