---
title: Implement register allocation hints
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:40.669422+02:00"
closed-at: "2026-01-07T06:30:27.158353+02:00"
---

File: src/regalloc/hints.zig. Hints bias allocator toward specific registers. ABI hints: parameters prefer X0-X7, return value prefers X0. Two-address hints: if dst must equal src (rare on ARM64), prefer same register. Improves allocation quality. Dependencies: linear scan. Effort: 1-2 days.
