---
title: IR float ops
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-02T23:54:16.626223+01:00\\\"\""
closed-at: "2026-02-03T10:07:11.682773+01:00"
close-reason: Declared IR float op terms
blocks:
  - hoist-ir-int-ops-17132fd2
---

File: src/dsl/isle/ir_prelude.isle:1; cause: float op terms (fadd/fsub/fmul/fdiv/fmin/fmax/fsqrt/fabs/fneg) undeclared; fix: add term decls with extern ctor/extractor; why: aarch64/riscv patterns depend on float ops.
