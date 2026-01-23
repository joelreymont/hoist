---
title: Add spectre_fence lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:52:39.414748+02:00\""
closed-at: "2026-01-23T14:58:06.162475+02:00"
---

In lower.isle, add spectre_fence: emit CSDB (conditional speculation barrier). Deps: Add select_spectre_guard. Verify: zig build test
