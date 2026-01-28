---
title: Generate rematerialization code
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:07:56.260360+02:00"
closed-at: "2026-01-07T06:30:44.175937+02:00"
---

File: src/regalloc/remat.zig - Implement insertRemat(vreg, use_inst). Clone def instruction before use. Example: iconst v5, 42 → insert before use. Update vreg to use new temp. Cheaper than LDR from spill slot. Dependencies: hoist-47b482858265e71f.
