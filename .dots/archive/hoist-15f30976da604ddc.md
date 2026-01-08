---
title: Create regalloc pipeline entry point
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T11:46:25.472400+02:00\""
closed-at: "2026-01-08T12:06:40.951489+02:00"
---

File: src/machinst/regalloc_pipeline.zig (new file). Wire liveness → linear scan allocator → result. Function takes VCode, returns RegAllocResult + final frame size. Add unit test with simple function. Dependencies: none. Effort: <30min
