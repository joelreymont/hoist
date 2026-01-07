---
title: "P2.11g-c: Add vector comparison lowering rules"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T09:25:18.200869+02:00"
closed-at: "2026-01-04T10:00:50.574497+02:00"
---

File: src/backends/aarch64/lower.isle around line 2142 - Add 8+ ISLE rules for fcmp/icmp with multi_lane types. Includes zero-optimized rules and general comparison rules. Depends on P2.11g-b for helpers.
