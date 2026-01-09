---
title: Define exception handling ABI for try_call
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T06:34:25.943985+02:00\""
closed-at: "2026-01-09T06:37:40.308556+02:00"
---

File: src/codegen/compile.zig:470-476 - Need to define how callees signal exceptions to callers. Options: (1) Reserved register (e.g., X19) set to non-zero on exception, (2) Return value encoding (e.g., X0 = null on exception, result ptr otherwise), (3) DWARF personality routine with stack unwinding. Once ABI defined, emit conditional check after BL instruction and branch to exception_successor VCode block (lookup from ir_to_vcode_blocks). Normal path falls through to normal_successor. Requires coordination with callee generation.
