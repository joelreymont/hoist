---
title: Emit jump table data after function
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:29:20.861478+02:00\""
closed-at: "2026-01-07T22:45:17.873491+02:00"
---

File: src/machinst/buffer.zig or emit integration - After emitting function code, emit jump table data as .word/.quad directives (or raw bytes). Place tables with proper alignment (4-byte for 32-bit offsets, 8-byte for 64-bit). Track table locations for PC-relative addressing. Depends on previous jump table structure work.
