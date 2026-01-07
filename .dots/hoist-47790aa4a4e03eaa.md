---
title: Fix test compilation errors
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T12:10:55.441133+02:00"
closed-at: "2026-01-03T12:17:10.746136+02:00"
---

File: multiple test failures

Errors found when running 'zig build test':
1. src/ir/verifier.zig:82 - SecondaryMap 'not a function' error
2. src/codegen/context.zig:40,64,73 - Function signature mismatches and missing 'clear' method
3. src/codegen/isle_ctx.zig:116,323 - RegClass type mismatch (machinst.reg vs codegen.lower_helpers)
4. src/codegen/optimize.zig:80 - Wrong argument count
5. src/codegen/opts/dce.zig:61,146 - SecondaryMap call error and missing 'fsqrt' opcode
6. src/ir/domtree.zig:64,201,212,308,572 - PrimaryMap.deinit and get() pointer/optional mismatches
7. src/ir/global_value_data.zig:125 - Missing 'isUser' method on ExternalName
8. src/ir/jump_table_data.zig:87 - Wrong argument count
9. Writer format string ambiguity errors

Root cause: Tests import different code paths that weren't exercised by 'zig build'. Need to fix API mismatches in test-specific code.
