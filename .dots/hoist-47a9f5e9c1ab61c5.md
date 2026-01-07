---
title: Implement rematerialization optimization
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:41.046454+02:00"
closed-at: "2026-01-06T11:07:41.903827+02:00"
---

File: src/regalloc/remat.zig. Instead of spilling a value, regenerate it when needed (if cheap). Examples: constants (iconst), simple address computations. Cost model: rematerialization cheaper than load from stack? Reduces memory traffic. Dependencies: spilling strategy. Effort: 2-3 days.
