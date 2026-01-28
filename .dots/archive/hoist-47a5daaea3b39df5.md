---
title: Implement imul lowering for AArch64
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T17:38:44.318143+02:00"
closed-at: "2026-01-05T17:48:01.106855+02:00"
---

File: tests/e2e_jit.zig:294 - E2E test expects i64 multiply to work (2*3=6) but currently returns wrong result (2). Need to implement .imul opcode lowering in src/backends/aarch64/lower.zig using MUL instruction. Add to lowerInst() switch, map to Inst.mul(rd, rn, rm). Reference: ARM Architecture Reference Manual for MUL encoding.
