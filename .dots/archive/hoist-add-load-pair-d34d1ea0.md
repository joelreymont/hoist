---
title: Add load-pair peephole
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:52:57.786630+02:00\""
closed-at: "2026-01-25T16:39:17.282905+02:00"
---

In src/codegen/peephole.zig:99, implement adjacent load combining to LDP. Deps: none. Verify: zig build test
