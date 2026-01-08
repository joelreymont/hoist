---
title: Add STP spill test
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T20:05:14.380515+02:00\""
closed-at: "2026-01-08T21:07:02.106746+02:00"
---

File: tests/e2e_jit.zig. Create test that forces 2 adjacent register spills (allocate all regs, then use 2 more). Verify disassembly contains STP instead of 2×STR. Check correct stack offset calculation. ~15 min.
