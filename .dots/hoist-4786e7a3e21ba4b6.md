---
title: Add iabs scalar lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T04:43:17.730850+02:00"
closed-at: "2026-01-04T04:44:47.873517+02:00"
---

File: src/backends/aarch64/lower.isle - Add ISLE rule for iabs opcode using CMP+NEG+CSEL pattern: cmp x,0; neg tmp,x; csel result,x,tmp,ge
