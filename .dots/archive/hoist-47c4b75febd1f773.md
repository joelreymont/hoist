---
title: Implement rematerialization in spill pass
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:27:55.942878+02:00"
closed-at: "2026-01-07T06:54:38.158737+02:00"
---

File: src/regalloc/linear_scan.zig - Add rematerialization: regenerate values instead of spilling/reloading when cheaper. Candidates: constants (iconst, fconst), simple arithmetic (lea, add imm). Cost model: Compare remat instruction count vs spill+reload (2 mem ops). In spillInterval(), check if vreg is rematerializable, if yes emit remat code instead of reload. Reduces memory traffic, improves performance. Optimization.
