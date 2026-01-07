---
title: Implement fcmp floating-point comparison
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:26:05.427399+02:00"
closed-at: "2026-01-06T10:34:02.713318+02:00"
---

File: src/codegen/compile.zig - Add lowering for fcmp operation. Use FCMP to set flags, then CSET with FP condition codes (eq/ne/lt/le/gt/ge/uno/ord). Handle NaN semantics correctly. Critical P0 operation.
