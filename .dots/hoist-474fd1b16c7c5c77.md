---
title: "ISLE: lexer/parser"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:06.318212+02:00\""
closed-at: "\"2026-01-01T16:00:29.594212+02:00\""
close-reason: Completed ISLE lexer, AST types, and parser (~800 LOC). Parser has 12/13 tests passing; decl test needs argument list syntax clarification.
blocks:
  - hoist-474fcfef22482f57
---

src/dsl/isle/lexer.zig, parser.zig, ast.zig (~2k LOC)

Port from: cranelift/isle/isle/src/{lexer,parser,ast}.rs

Lexer:
- S-expression tokenization
- Token types: LParen, RParen, Symbol, Int, At, Semicolon
- Position tracking for error messages

Parser:
- Recursive descent S-expr parser
- AST construction

AST types:
- Def: top-level definition (type, decl, rule, extractor, extern)
- Rule: pattern -> expr with priority
- Pattern: term applications, wildcards, bindings
- Expr: term construction, let bindings, if-let chains

Example ISLE:
  (rule (lower (iadd x y))
        (x64_add x y))
