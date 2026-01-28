---
title: Implement store memory store operation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:26:29.724904+02:00"
closed-at: "2026-01-06T10:35:55.565939+02:00"
---

File: src/codegen/compile.zig - Add lowering for store operation. Emit STR with base+offset addressing mode. Handle different sizes (8/16/32/64-bit). Check offset range, legalize if needed. Critical P0 - needed for all memory writes.
