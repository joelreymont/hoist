---
title: Add select_spectre_guard
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:52:39.410196+02:00"
---

In lower.isle, add select_spectre_guard lowering. Use CSEL with speculation barrier. Deps: none. Verify: zig build test
