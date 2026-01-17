---
title: Add usub_overflow lowering
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:59.405062+02:00"
---

In aarch64_lower_generated.zig, add usub_overflow: SUBS + CSET CC. Deps: Add sadd_overflow lowering. Verify: zig build test
