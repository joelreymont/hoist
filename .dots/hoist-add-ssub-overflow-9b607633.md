---
title: Add ssub_overflow lowering
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:59.410295+02:00"
---

In aarch64_lower_generated.zig, add ssub_overflow: SUBS + CSET VS. Deps: Add usub_overflow lowering. Verify: zig build test
