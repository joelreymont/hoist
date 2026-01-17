---
title: Add store-pair peephole
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:52:57.791499+02:00"
---

In src/codegen/peephole.zig:117, implement adjacent store combining to STP. Deps: Add load-pair peephole. Verify: zig build test
