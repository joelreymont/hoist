---
title: IR mem/ctrl
status: open
priority: 1
issue-type: task
created-at: "2026-02-02T23:54:24.398238+01:00"
blocks:
  - hoist-ir-cmp-cvt-be8603ec
---

File: src/dsl/isle/ir_prelude.isle:1; cause: load/store/jump/brif/return/trap/global_value terms undeclared; fix: add mem/control-flow term decls with extern ctor/extractor; why: ISLE lowering references these ops.
