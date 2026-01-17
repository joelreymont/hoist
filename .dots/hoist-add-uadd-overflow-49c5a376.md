---
title: Add uadd_overflow lowering
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:51:59.394306+02:00"
---

In src/generated/aarch64_lower_generated.zig, add uadd_overflow: ADDS + CSET. Set result and overflow flag. Deps: none. Verify: zig build test
