---
title: Fix default arch
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-17T12:46:36.916794+02:00\\\"\""
closed-at: "2026-01-17T13:25:07.658619+02:00"
---

Files: src/context.zig:34-37, src/codegen/compile.zig:978-983, src/codegen/compile.zig:4722-4725. Cause: default arch x86_64 but lowering stub errors. Fix: default to supported arch and return explicit error on unsupported arch; gate lowering with clear error. Why: compileFunction should succeed by default and fail explicitly when unsupported. Verify: zig build test; add unit test for unsupported arch error.
