---
title: Fix CodegenResult Panics
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.553598+01:00\""
closed-at: "2026-02-01T20:42:25.916132+01:00"
close-reason: "completed: CodegenResult.unwrap/unwrapErr return errors (src/codegen/error.zig:122-133) and tests assert error.UnwrapErr/UnwrapOk"
---

Context: src/codegen/error.zig:125; cause: unwrap/unwrapErr panics; fix: remove or replace with error-returning APIs; deps: hoist-remove-panics-and-a0d5efe0; verification: codegen tests
