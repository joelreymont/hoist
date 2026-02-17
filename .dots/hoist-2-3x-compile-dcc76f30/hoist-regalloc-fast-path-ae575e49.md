---
title: Regalloc fast path
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T11:42:08.504532+01:00"
---

Optimize linear-scan/regalloc2 hot loops and spill bookkeeping. files: src/regalloc/linear_scan.zig, src/machinst/regalloc.zig. Cause: interval processing and spill metadata dominate large functions. Fix: tighten data layout, remove redundant passes, and preallocate interval vectors. Why: reduce compile time for 1k-5k inst benches.
