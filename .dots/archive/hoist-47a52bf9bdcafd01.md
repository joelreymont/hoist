---
title: Add isMove() and isTerm() to Inst
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:49:53.227222+02:00"
closed-at: "2026-01-05T17:01:27.300787+02:00"
---

File: src/backends/aarch64/inst.zig - Add 'pub fn isMove(self: Inst) bool' - return true for mov_rr. Add 'pub fn isTerm(self: Inst) bool' - return true for ret, br, br_cond. Needed for regalloc move coalescing and control flow analysis. Reference Cranelift MachInst trait. ~10 LOC.
