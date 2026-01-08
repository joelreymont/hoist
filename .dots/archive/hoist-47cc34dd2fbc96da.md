---
title: Spill slot infrastructure
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T15:24:06.075338+02:00\""
closed-at: "2026-01-08T11:46:38.517210+02:00"
---

Integrate spill slots with stack frame. Allocate spill slots on demand in register allocator. Track spill slot → VReg mapping. Calculate spill area size. Test: Allocate 10 spill slots. Depends on dot 1.3. Phase 1.5, Priority P0
