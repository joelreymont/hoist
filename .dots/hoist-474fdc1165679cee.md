---
title: "quality: test suite"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:03:00.380016+02:00\""
closed-at: "\"2026-01-01T17:16:53.507782+02:00\""
close-reason: "\"completed: comprehensive test suite - tests/{compile_simple,compile_loops,x64_encoding,aarch64_encoding}.zig (1073 LOC total, unit + integration tests)\""
blocks:
  - hoist-474fdc115587ddee
---

tests/ (~comprehensive)

Test categories:

Unit tests (in each module):
- Entity operations
- IR construction
- Type operations
- Instruction encoding

Integration tests (tests/):
- tests/compile_simple.zig - basic functions
- tests/compile_loops.zig - control flow
- tests/compile_calls.zig - ABI testing
- tests/x64_encoding.zig - byte-level encoding
- tests/aarch64_encoding.zig

Differential tests:
- Compare output vs Cranelift Rust
- Same IR -> same machine code

FileCheck-style tests:
- IR input -> expected assembly output
- Verify instruction selection

Target: 100+ tests, all passing
