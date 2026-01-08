---
title: Generate branch to landing pad
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:07:26.046015+02:00"
---

File: src/backends/aarch64/lower.isle. Lower try_call: emit BL (call), then on exception path emit B to landing pad block. Need conditional branch based on exception indicator (TBD: return value or separate mechanism). ~25 min.
