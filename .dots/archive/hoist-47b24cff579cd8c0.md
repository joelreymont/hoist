---
title: Add SBCS instruction variant
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.817257+02:00"
closed-at: "2026-01-06T08:45:26.214217+02:00"
---

File: src/backends/aarch64/inst.zig. Add sbcs (Subtract with Carry and Set flags) instruction variant after subs_rr at line ~132. Structure: dst, src1, src2, size. Needed for multi-word subtraction. Effort: 15 min.
