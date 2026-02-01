---
title: Add partial decl and error unions
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T21:40:24.001471+01:00\\\"\""
closed-at: "2026-02-01T18:22:30.055230+01:00"
close-reason: "completed: partial parsed (src/dsl/isle/parser.zig:242-292), stored in AST/sema (src/dsl/isle/ast.zig:67-73, src/dsl/isle/sema.zig:581-615), codegen uses partial for !?/extern wrappers (src/dsl/isle/codegen.zig:131-158, src/dsl/isle/codegen/constructors.zig:84-103)"
---

Context: src/dsl/isle/parser.zig:230, src/dsl/isle/ast.zig:67, src/dsl/isle/sema.zig:560, src/dsl/isle/codegen/constructors.zig:40, src/dsl/isle/codegen.zig:90; cause: pure flag misused for fallibility and context stubs return error for non-error types; fix: add partial flag in AST/sema, parse partial keyword, use partial for optional returns, emit ! for extern calls, update tests; deps: none; verification: NO_COLOR=1 zig build test
