---
title: Add ir parser
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.671106+02:00\""
closed-at: "2026-01-23T19:42:51.450436+02:00"
---

Files: docs/ir.md:79-112, src/ir/builder.zig:1-120
Root cause: no IR text parser to build Function/DFG.
Fix: add src/ir/text/parser.zig to parse types, blocks, insts into IR.
Why: clif reader parity and filetests.
Deps: Add ir lexer.
Verify: parser round-trip tests.
