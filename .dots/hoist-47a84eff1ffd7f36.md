---
title: Fix redundant mov_rr generation
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T20:34:25.684489+02:00"
closed-at: "2026-01-05T21:00:58.396505+02:00"
---

File: src/codegen/compile.zig - IR lowering generates redundant 'mov_rr dst=w0 src=w0' after iconst. Debug output shows: Inst 0: mov_imm, Inst 1: mov_rr w0←w0, Inst 2: ret. The mov_rr is unnecessary and may be corrupting w0. Need to find where this is generated in lowering and remove it.
