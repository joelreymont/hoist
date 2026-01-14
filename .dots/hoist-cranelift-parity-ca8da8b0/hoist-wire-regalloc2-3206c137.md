---
title: Wire regalloc2
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.746924+02:00"
---

Files: src/machinst/regalloc_pipeline.zig:1-80
Root cause: pipeline uses linear scan only.
Fix: integrate regalloc2 core into pipeline and expose config.
Why: production-quality allocation.
Deps: Add regalloc2 core.
Verify: regalloc pipeline tests.
