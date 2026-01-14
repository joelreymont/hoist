---
title: Add x64 operands
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.325442+02:00"
---

Files: src/backends/x64/inst.zig:12-93, src/backends/aarch64/inst.zig:2463-2475
Root cause: x64 Inst lacks getOperands for regalloc.
Fix: add OperandCollector + getOperands for each x64 inst, mirroring aarch64 patterns.
Why: regalloc needs def/use info.
Deps: Add x64 alu, Add x64 mem, Add x64 branch, Add x64 simd, Add x64 atom.
Verify: add operand collection tests.
