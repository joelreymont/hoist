---
title: Wire linear scan to compile pipeline
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:41:47.858701+02:00"
closed-at: "2026-01-06T22:47:35.956081+02:00"
---

File: src/backends/aarch64/compile.zig - Replace trivial allocator with LinearScanAllocator in emitAArch64WithAllocation. Need to: 1) Import linear_scan module, 2) Compute liveness from inst list, 3) Initialize LinearScanAllocator with AArch64 register counts (31 int, 32 float, 32 vector), 4) Call allocate() method, 5) Handle error.OutOfRegisters by falling back to trivial or panicking
