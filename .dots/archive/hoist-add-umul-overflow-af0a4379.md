---
title: Add umul_overflow lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:52:07.364792+02:00\""
closed-at: "2026-01-23T14:54:04.388445+02:00"
---

In aarch64_lower_generated.zig, add umul_overflow: UMULH + compare for overflow. Deps: Add ssub_overflow lowering. Verify: zig build test
