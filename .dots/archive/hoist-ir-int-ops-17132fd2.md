---
title: IR int ops
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:12.473659+01:00\\\"\""
closed-at: "2026-02-03T09:27:14.934301+01:00"
close-reason: Declared IR int op terms
blocks:
  - hoist-ir-types-73db7c85
---

File: src/dsl/isle/ir_prelude.isle:1; cause: integer/bitwise op terms (iadd/isub/imul/band/bor/bxor/bnot/ishl/ushr/sshr/rotl/rotr) undeclared; fix: add term decls with extern ctor/extractor; why: lower patterns reference these ops.
