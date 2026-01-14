---
title: Add rv isa
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.436396+02:00"
---

Files: src/backends/x64/isa.zig:1-60, src/context.zig:61-88
Root cause: riscv64 ISA not wired into compile pipeline.
Fix: add src/backends/riscv64/isa.zig and integrate compileFunction.
Why: enable riscv64 compilation.
Deps: Add rv insts, Add rv abi, Wire rv lower.
Verify: compile smoke tests.
