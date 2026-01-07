---
title: Add br_table lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:42:33.695662+02:00"
closed-at: "2026-01-06T22:57:26.468249+02:00"
---

File: src/backends/aarch64/lower.isle - Implement br_table (jump table) lowering. Need: 1) ISLE rule for br_table opcode, 2) Bounds check index against table size, 3) Load jump target from table base + index*8, 4) Indirect branch to target. May need new Inst variant for jump table and new encoding in inst.zig
