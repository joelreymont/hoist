---
title: Enforce frame pointer for large/dynamic frames
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:06:34.759781+02:00"
closed-at: "2026-01-07T06:30:27.186462+02:00"
---

File: src/backends/aarch64/abi.zig - In computeFrameLayout: if frame_size>512 OR has_dynamic_alloca, set needs_frame_pointer=true. In prologue: always save/setup FP. Used for unwinding and accessing locals with fixed offsets from FP. Dependencies: hoist-47b47c0bd288f9c1.
