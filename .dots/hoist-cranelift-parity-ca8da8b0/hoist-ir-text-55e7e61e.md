---
title: IR text
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:25.281477+02:00\""
closed-at: "2026-01-14T15:42:57.173275+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: ~/Work/wasmtime/cranelift/docs/index.md:36-38 (reader), ~/Work/wasmtime/cranelift/docs/testing.md:23-32 (clif test file format), /Users/joel/Work/hoist/docs/ir.md:1-112 (Hoist IR spec). Root cause: no textual IR parser/printer or .clif equivalent. Fix: implement IR text grammar, parser, and printer; integrate with tests. Why: parity with Cranelift reader + filetests.
