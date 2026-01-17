---
title: Add dead move elim peephole
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:07.169397+02:00"
---

In src/codegen/peephole.zig:127, implement dead move elimination. Remove MOV rx, rx. Deps: Add store-pair peephole. Verify: zig build test
