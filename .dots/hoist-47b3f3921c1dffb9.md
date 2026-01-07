---
title: Implement func_addr load function address
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:27:51.420966+02:00"
closed-at: "2026-01-06T20:38:01.229427+02:00"
---

File: src/codegen/compile.zig - Add lowering for func_addr. Use ADRP+ADD to compute function pointer. Needed for indirect calls. P1 operation.
