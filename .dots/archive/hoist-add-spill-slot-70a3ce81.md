---
title: Add spill slot bounds test
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T21:47:58.852454+01:00\\\"\""
closed-at: "2026-02-06T21:50:44.572184+01:00"
close-reason: Added regalloc bridge test for oversized spill slot offsets
---

src/backends/aarch64/regalloc_bridge.zig: spillOffset casts slot index to i16. Add regression test to ensure oversized spill slot index returns SpillSlotOffsetOutOfRange during applyAllocations (no silent truncation). Verification: zig build test -j1 --global-cache-dir .zig-global-cache.
