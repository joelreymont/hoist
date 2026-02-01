---
title: ISLE builtin primitives
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-01T21:54:43.051566+01:00\\\"\""
closed-at: "2026-02-01T22:13:45.236944+01:00"
close-reason: completed
---

Context: src/dsl/isle/sema.zig: TypeEnv.init/Compiler.init; cause: ISLE compiler assumes bool type id 0 and .isle files use u8/u32/u64 without declaring types; fix: prepopulate TypeEnv with builtin bool/unit + primitive numeric types and add tests; why: compile lower/opts ISLE without manual type defs and keep bool id stable; verification: NO_COLOR=1 zig build test
