---
title: Add sadd_overflow lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:51:59.399601+02:00\""
closed-at: "2026-01-23T14:53:24.960978+02:00"
---

In aarch64_lower_generated.zig, add sadd_overflow: ADDS + CSET VS. Handle signed overflow. Deps: Add uadd_overflow lowering. Verify: zig build test
