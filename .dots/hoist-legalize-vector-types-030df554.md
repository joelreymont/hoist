---
title: Legalize vector types
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.912016+01:00"
blocks:
  - hoist-split-wide-types-77640c9e
---

Context: src/codegen/compile.zig:1313; cause: vector legalization TODO; fix: lower unsupported vectors or split into scalars; deps: legalizer infra; verification: add vector legalization tests + zig build test
