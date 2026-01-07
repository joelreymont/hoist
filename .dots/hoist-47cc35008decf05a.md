---
title: Linear scan allocator
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:08.393210+02:00"
---

MOVED from Phase 3 (oracle: doesn't depend on spilling). Implement linear scan algorithm. Build live intervals for all vregs. Active list management. Expire old intervals. Test: Allocate registers for 20-vreg function. Phase 1.11, Priority P0
