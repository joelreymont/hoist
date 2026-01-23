---
title: Add const pool subsumption
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:13.554909+02:00\""
closed-at: "2026-01-25T20:45:41.691573+02:00"
---

In src/codegen/const_pool.zig, implement subsumption deduplication. Allow larger constants to subsume smaller. Match Cranelift. Deps: none. Verify: zig build test
