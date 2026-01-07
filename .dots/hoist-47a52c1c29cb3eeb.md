---
title: Implement vreg rewriting in emitAArch64VCode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:49:55.483093+02:00"
closed-at: "2026-01-05T17:01:27.322475+02:00"
---

File: src/codegen/compile.zig:emitAArch64VCode() - For each inst in vcode.insns: create temp copy, call getOperands() on copy with rewriting collector that replaces vregs with allocator.getAllocation(). Then call emit_mod.emit(rewritten_inst, buffer). Pattern from Cranelift vcode.rs:1017-1040. ~30 LOC.
