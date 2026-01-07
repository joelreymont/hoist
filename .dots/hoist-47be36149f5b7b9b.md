---
title: Add SpillSlot allocation infrastructure
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:42:16.943466+02:00"
closed-at: "2026-01-06T22:53:50.543002+02:00"
---

File: src/regalloc/linear_scan.zig - Need to track spilled vregs and allocate stack slots. Add: 1) SpillSlot type wrapping stack offset, 2) vreg_to_spill: HashMap(u32, SpillSlot) in RegAllocResult, 3) next_spill_offset: u32 counter in LinearScanAllocator, 4) allocateSpillSlot() method returning new SpillSlot, 5) getSpillSlot() in RegAllocResult
