---
title: Add compilation state fields to Context
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T09:35:35.409602+02:00"
closed-at: "2026-01-05T09:37:46.005518+02:00"
---

File: src/context.zig:13 - Context struct needs: func: *Function field, cfg: ControlFlowGraph field, compiled_code field, getCompiledCode() method. These are needed by compile.zig compile() function which expects to work on stateful context. Root cause: context.zig Context is high-level API context, but compile() needs compilation-specific state. Fix: Add optional compilation state fields to Context, populated during compileFunction(). Depends on Context refactor.
