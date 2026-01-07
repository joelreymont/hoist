---
title: Constant pool for vector constants
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T16:42:45.785138+02:00"
---

File: src/backends/aarch64/isle_impl.zig - aarch64_shuffle_tbl requires loading 128-bit shuffle masks into vector registers. Need constant pool infrastructure to emit literal loads. Blocks TBL shuffle fallback. Related to hoist-47cc379aa8811854 (constant pool data structure).
