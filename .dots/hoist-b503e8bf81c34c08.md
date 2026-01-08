---
title: Track copy instructions
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:05:57.069045+02:00"
---

File: src/regalloc/trivial.zig. Add CopyList to track all MOV vreg->vreg copies. Store src/dst vreg pairs with block location. Collect during initial scan. ArrayList(struct{src, dst, block, inst_idx}). ~15 min.
