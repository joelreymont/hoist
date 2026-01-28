---
title: Create ABI compliance test suite
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:42.183142+02:00"
closed-at: "2026-01-06T11:09:06.137992+02:00"
---

File: tests/codegen/aarch64_abi_tests.zig. Test parameter passing for all types (i8, i16, i32, i64, i128, f32, f64, vectors, structs). Test return values. Test stack alignment (16-byte). Test HFA/HVA. Test callee-save register preservation. Compare generated code against reference compiler (clang). Effort: 3-5 days.
