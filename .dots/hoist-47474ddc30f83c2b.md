---
title: Generate aarch64 lowering from ISLE
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T00:50:34.790146+02:00\""
closed-at: "\"2026-01-01T04:12:17.584302+02:00\""
blocks:
  - hoist-47474d1ab33cfac0
---

Run retargeted ISLE on ../wasmtime/cranelift/codegen/src/isa/aarch64/lower.isle (3.3k LOC rules). Generates Zig switch statements for instruction selection. Test with simple functions first.
