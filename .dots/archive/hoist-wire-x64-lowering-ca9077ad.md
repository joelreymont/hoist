---
title: Wire x64 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.715085+01:00\\\"\""
closed-at: "2026-02-06T17:36:24.373708+01:00"
close-reason: Wired x64 lowering path and fixed x64 backend build/test issues
blocks:
  - hoist-indirect-return-b3ed0b57
---

Context: src/codegen/compile.zig:4939-4943; cause: x86-64 lowering returns UnsupportedTarget; fix: dispatch to x64 lowerer and propagate errors; deps: Lower x64 ALU, Lower x64 branches; verification: zig build test
