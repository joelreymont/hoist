---
title: Add simple missing ARM64 opcodes
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T04:49:08.667314+02:00"
closed-at: "2026-01-04T04:51:48.248333+02:00"
---

Files: lower.isle, isle_helpers.zig - Quick wins: fneg (if missing), fabs (if missing), avg_round (if has URHADD/SRHADD), check what other simple scalar/vector ops are not lowered
