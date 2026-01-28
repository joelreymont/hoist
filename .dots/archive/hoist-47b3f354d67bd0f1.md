---
title: Implement symbol_value load symbol address
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:27:47.405449+02:00"
closed-at: "2026-01-06T20:38:09.151144+02:00"
---

File: src/codegen/compile.zig - Add lowering for symbol_value. Similar to global_value, use ADRP+ADD to compute symbol address. P1 operation.
