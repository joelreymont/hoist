---
title: Identify rematerializable values
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T20:06:38.177646+02:00\""
closed-at: "2026-01-08T21:14:44.904880+02:00"
---

File: src/regalloc/remat.zig (new). Detect cheap-to-recompute values: iconst, simple ALU ops (add imm, shift imm), null ptrs. Mark values as rematerializable with cost estimate. Store in HashMap(Vreg, RematInfo). ~20 min.
