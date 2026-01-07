---
title: Implement iconcat/isplit lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:29.733255+02:00"
closed-at: "2026-01-06T08:25:37.102731+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcodes: iconcat, isplit. Operations: combine/split i32→i64 or i64→i128 using register pairs. Required for ABI and 128-bit operations. Dependencies: register allocator must handle pairs. Effort: 1 day.
