---
title: Wire Emit and AssembleResult
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.441251+01:00"
---

Context: src/codegen/compile.zig:5031; cause: emit stub; fix: emit MachBuffer and call assembleResult to fill CompiledCode; deps: hoist-wire-regalloc-and-b0b3a9b4; verification: compile_simple + e2e_jit
