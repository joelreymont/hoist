---
title: Implement load/store lowering for aarch64
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T08:34:12.611166+02:00"
closed-at: "2026-01-07T08:51:23.842948+02:00"
---

File: src/generated/aarch64_lower_generated.zig lower() function. Add patterns: (1) .load: get addr value → vreg, allocate dst vreg, emit ldr with offset 0. (2) .store: get val/addr vregs, emit str with offset 0. Use LoadData/StoreData from instruction_data. ~40 lines. Depends on: hoist-47c67a96b9f11e08.
