---
title: "ISLE: semantic analysis"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:06.322440+02:00\""
closed-at: "\"2026-01-01T16:04:59.021393+02:00\""
close-reason: Completed ISLE semantic analysis (~717 LOC). Implemented TypeEnv, TermEnv, Compiler with type checking, AST-to-semantic IR conversion, pattern/expression type checking.
blocks:
  - hoist-474fd1b16c7c5c77
---

src/dsl/isle/sema.zig (~1.5k LOC)

Port from: cranelift/isle/isle/src/sema.rs

Semantic analysis phase:
- Type checking of patterns and expressions
- Term resolution (map names to definitions)
- Rule validation (patterns must be exhaustive types)
- Extractor binding analysis

Key structures:
- TypeEnv: maps type names to TypeId
- TermEnv: maps term names to TermId  
- RuleEnv: validated rules with resolved references

Errors:
- Undefined type/term references
- Type mismatches in patterns
- Invalid extractor signatures
