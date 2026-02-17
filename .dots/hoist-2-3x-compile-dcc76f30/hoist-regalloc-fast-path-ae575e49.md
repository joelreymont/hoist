---
title: Regalloc fast path
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T11:42:08.504532+01:00\\\"\""
closed-at: "2026-02-17T12:00:08.860411+01:00"
close-reason: sorted active intervals by end, prefix expiry, in-place range sort, added unsorted-range test; validated with test+bench
---

Optimize linear-scan/regalloc2 hot loops and spill bookkeeping. files: src/regalloc/linear_scan.zig, src/machinst/regalloc.zig. Cause: interval processing and spill metadata dominate large functions. Fix: tighten data layout, remove redundant passes, and preallocate interval vectors. Why: reduce compile time for 1k-5k inst benches.
