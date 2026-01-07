---
title: Add LinearScan allocator skeleton
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:00:04.049212+02:00"
closed-at: "2026-01-06T22:29:21.808599+02:00"
---

File: src/regalloc/linear_scan.zig - Create LinearScanAllocator struct: active (ArrayList of LiveRange), inactive, free_regs (BitSet per class). Add init/deinit. Add allocate(func, liveness) -> RegAllocResult stub. Dependencies: hoist-47b464cbac33aee0.
