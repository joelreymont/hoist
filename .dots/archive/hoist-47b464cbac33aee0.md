---
title: Add LiveRange data structure
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:59:31.018818+02:00"
closed-at: "2026-01-06T22:24:37.667379+02:00"
---

File: src/regalloc/liveness.zig - Create LiveRange struct: vreg, start_inst (u32), end_inst (u32), reg_class. Create LivenessInfo: ArrayList(LiveRange), vreg->range lookup map. Dependencies: none.
