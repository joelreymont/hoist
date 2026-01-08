---
title: Implement STP encoding
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T20:05:01.076144+02:00\""
closed-at: "2026-01-08T21:05:39.116365+02:00"
---

File: src/backends/aarch64/emit.zig. Add emitStp() for STP encoding. Format: bits[31:30]=size, [29:23]=0101001, [22]=index, [21:15]=imm7, [14:10]=Rt2, [9:5]=Rn, [4:0]=Rt1. Verify 8-byte alignment of offset. ~20 min.
