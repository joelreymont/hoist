---
title: Interpreter
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-14T15:06:39.610434+02:00\""
closed-at: "2026-01-14T15:42:57.205118+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: ~/Work/wasmtime/cranelift/interpreter/README.md:1-2 (IR interpreter), /Users/joel/Work/hoist/src (no interpreter module). Root cause: no IR interpreter for validation/debugging. Fix: add IR interpreter with opcode coverage + tests. Why: parity with Cranelift interpreter tooling.
