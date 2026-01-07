---
title: Implement ADRP+ADD for globals
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:31.111351+02:00"
closed-at: "2026-01-06T19:35:23.027460+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower global address materialization to ADRP+ADD sequence for PC-relative addressing. Handle GOT entries and direct globals. Reference: Cranelift lower.isle global patterns. Part of Phase 2 core functionality. Estimate: 1 day.
