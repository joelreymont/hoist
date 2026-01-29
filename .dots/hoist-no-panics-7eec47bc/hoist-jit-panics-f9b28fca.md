---
title: JIT panics
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-29T12:35:48.972203+01:00\\\"\""
closed-at: "2026-01-29T13:06:41.729078+01:00"
close-reason: completed
---

File: src/jit/module.zig:224; cause: @panic/unreachable on uninit data/symbols; fix: return errors and propagate; why: avoid masking.
