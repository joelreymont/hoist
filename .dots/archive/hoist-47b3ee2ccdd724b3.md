---
title: Implement call_indirect indirect function call
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:26:20.895714+02:00"
closed-at: "2026-01-06T20:12:02.593928+02:00"
---

File: src/codegen/compile.zig - Add lowering for call_indirect operation. Load function pointer into register, emit BLR (branch-and-link register). Handle ABI same as call. Critical P0.
