---
title: Split wide types
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.904774+01:00\\\"\""
closed-at: "2026-02-06T09:06:54.614587+01:00"
close-reason: Implemented i128 pair lowering and tests
blocks:
  - hoist-legalize-narrow-types-33b7b6fa
---

Context: src/codegen/compile.zig:1310; cause: wide type split TODO; fix: split ops into legal-width pairs; deps: legalizer infra; verification: add legalization tests + zig build test
