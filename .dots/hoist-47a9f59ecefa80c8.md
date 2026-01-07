---
title: Implement aggregate argument classification and HFA/HVA
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:36.134660+02:00"
closed-at: "2026-01-06T11:04:06.069559+02:00"
---

File: src/backends/aarch64/abi.zig. Homogeneous Float Aggregate (HFA): struct with 2-4 floats → pass in V0-V7. HVA: vectors. Non-homogeneous or >4 elements → pass by reference (pointer in X register). Size >16 bytes → indirect. Dependencies: type introspection. Effort: 2-3 days.
