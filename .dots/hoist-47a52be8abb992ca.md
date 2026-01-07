---
title: Implement getOperands() for mov_imm
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:49:52.108485+02:00"
closed-at: "2026-01-05T17:01:27.289841+02:00"
---

File: src/backends/aarch64/inst.zig - Add 'pub fn getOperands(self: *Inst, collector: *OperandCollector)' method. For mov_imm case: collector.regDef(self.mov_imm.dst). References Cranelift aarch64/inst/mod.rs:354-453 aarch64_get_operands() pattern. mov_imm only writes dst register, no reads. ~5 LOC.
