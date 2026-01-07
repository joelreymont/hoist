---
title: Add frame size calculation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:06:01.098901+02:00"
closed-at: "2026-01-06T21:48:11.670265+02:00"
---

File: src/backends/aarch64/abi.zig - In computeFrameLayout: total = spill_slots + local_slots + callee_saves + call_arg_area. Round up to 16-byte alignment. If >4KB, set needs_stack_probe flag. If >256KB, set needs_large_frame flag. Dependencies: hoist-47b47b175c5a006e, hoist-47b461a5391e71af.
