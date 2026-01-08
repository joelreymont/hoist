---
title: Add STP instruction variant
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T20:04:54.908256+02:00\""
closed-at: "2026-01-08T21:02:14.108923+02:00"
---

File: src/backends/aarch64/inst.zig. Add Inst.stp_imm_pre variant for paired store with pre-index addressing: STP Xt1, Xt2, [Xn, #imm]!. Fields: rt1/rt2 (source regs), rn (base), offset (i7). ~10 min.
