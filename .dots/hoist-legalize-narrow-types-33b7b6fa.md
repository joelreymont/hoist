---
title: Legalize narrow types
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.897695+01:00"
blocks:
  - hoist-implement-licm-pass-a4ae5025
---

Context: src/codegen/compile.zig:1307; cause: narrow type widening TODO; fix: insert widen ops to legal width; deps: type legalizer design; verification: add legalization tests + zig build test
