---
title: Spill coalescing
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T15:24:07.239078+02:00\""
closed-at: "2026-01-08T20:05:18.933401+02:00"
---

NEW (oracle recommendation). Detect adjacent spill slots. Use STP instead of 2×STR where possible. Verify alignment for paired stores. Test: Spill 2 adjacent registers → STP. Phase 1.8, Priority P1
