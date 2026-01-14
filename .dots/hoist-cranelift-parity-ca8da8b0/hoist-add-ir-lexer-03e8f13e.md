---
title: Add ir lexer
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.665360+02:00"
---

Files: docs/ir.md:79-112, /Users/joel/Work/wasmtime/cranelift/reader/README.md:1-3
Root cause: no IR text lexer/parsing infrastructure.
Fix: add src/ir/text/lexer.zig to tokenize IR text format.
Why: CLIF-style reader support.
Deps: none.
Verify: lexer unit tests.
