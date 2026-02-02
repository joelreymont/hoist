---
title: Legalize types
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.784936+01:00"
blocks:
  - hoist-integrate-regalloc2-8f36d248
---

Context: src/codegen/compile.zig:1290-1326; cause: legalization TODOs for narrow/wide/vector types; fix: implement target-specific type and op legalization; deps: none; verification: zig build test
