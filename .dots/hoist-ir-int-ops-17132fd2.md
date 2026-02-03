---
title: IR int ops
status: open
priority: 1
issue-type: task
created-at: "2026-02-02T23:54:12.473659+01:00"
blocks:
  - hoist-ir-types-73db7c85
---

File: src/dsl/isle/ir_prelude.isle:1; cause: integer/bitwise op terms (iadd/isub/imul/band/bor/bxor/bnot/ishl/ushr/sshr/rotl/rotr) undeclared; fix: add term decls with extern ctor/extractor; why: lower patterns reference these ops.
