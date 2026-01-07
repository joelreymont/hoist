---
title: "integration: context API"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:03:00.370658+02:00\""
closed-at: "\"2026-01-01T17:13:11.946275+02:00\""
close-reason: "\"completed: src/context.zig provides unified compilation API with target config, opt level, verification/optimization toggles, and compileFunction orchestration\""
blocks:
  - hoist-474fd9fee297975a
---

src/context.zig (~600 LOC)

Port from: cranelift/codegen/src/context.rs

Top-level compilation API:

Context struct:
- settings: CompileSettings
- isa: TargetIsa (x64 or aarch64)

Main entry points:
- compile(func: *Function) -> CompiledCode
- optimize(func: *Function) - apply opts in place

Pipeline orchestration:
1. Verify input IR (debug mode)
2. Apply ISLE optimizations
3. Lower to MachInsts
4. Register allocation
5. Binary emission
6. Return CompiledCode

CompileSettings:
- opt_level: none, speed, speed_and_size
- enable_verifier: bool
- enable_probestack: bool

MILESTONE: End-to-end compilation API!
