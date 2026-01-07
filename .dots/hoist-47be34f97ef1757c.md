---
title: Add linear scan allocator tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:41:58.388481+02:00"
closed-at: "2026-01-06T22:44:52.734913+02:00"
---

File: src/regalloc/linear_scan.zig - Add tests for allocate() method. Test: 1) Simple non-overlapping ranges allocate to different regs, 2) Overlapping ranges cause different regs, 3) Sequential ranges reuse registers, 4) Different register classes allocated independently, 5) Out of registers triggers error.OutOfRegisters
