---
title: Legalize narrow types
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.897695+01:00\""
closed-at: "2026-02-06T00:57:20.328748+01:00"
close-reason: Covered by target-specific legalizer wiring and tests
blocks:
  - hoist-implement-licm-pass-a4ae5025
---

Context: src/codegen/compile.zig:1307; cause: narrow type widening TODO; fix: insert widen ops to legal width; deps: type legalizer design; verification: add legalization tests + zig build test
