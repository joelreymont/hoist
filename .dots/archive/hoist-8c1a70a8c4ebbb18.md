---
title: Identify coalesceable copies
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T20:06:08.246137+02:00\""
closed-at: "2026-01-08T21:14:44.887208+02:00"
---

File: src/regalloc/coalesce.zig (new). For each copy, check interference graph: if src and dst don't interfere, mark as coalesceable. Check ABI constraints (e.g., don't coalesce across call if one is caller-save). ~20 min.
