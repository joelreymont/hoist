---
title: Add store-pair peephole
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:52:57.791499+02:00\""
closed-at: "2026-01-25T16:39:18.478604+02:00"
---

In src/codegen/peephole.zig:117, implement adjacent store combining to STP. Deps: Add load-pair peephole. Verify: zig build test
