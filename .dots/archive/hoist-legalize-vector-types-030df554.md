---
title: Legalize vector types
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.912016+01:00\\\"\""
closed-at: "2026-02-06T09:15:40.668033+01:00"
close-reason: widen/split legalization fixed; tests pass
blocks:
  - hoist-split-wide-types-77640c9e
---

Context: src/codegen/compile.zig:1313; cause: vector legalization TODO; fix: lower unsupported vectors or split into scalars; deps: legalizer infra; verification: add vector legalization tests + zig build test
