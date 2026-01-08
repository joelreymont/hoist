---
title: Connect frame size from regalloc to emission
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T11:46:25.531568+02:00\""
closed-at: "2026-01-08T12:11:29.529260+02:00"
---

File: src/backends/aarch64/isa.zig. Extract next_spill_offset from allocator. Add to computed stack frame size in prologue emission. Add test verifying frame size includes spill area. Dependencies: none. Effort: <30min
