---
title: Add spill slot adjacency tracking
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:04:41.554199+02:00"
---

File: src/regalloc/trivial.zig. Add SpillSlotMap to track which vregs spilled to adjacent slots (e.g., slots N and N+1 for 8-byte slots). Store in TrivialAllocator struct. Need: HashMap(SpillSlot, SpillSlot) for adjacent pair tracking. ~15 min.
