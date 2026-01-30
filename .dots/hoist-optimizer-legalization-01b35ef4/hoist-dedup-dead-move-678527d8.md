---
title: Dedup dead-move peephole
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-30T13:27:32.607830+01:00\\\"\""
closed-at: "2026-01-30T13:28:28.217551+01:00"
close-reason: completed
---

Context: src/backends/aarch64/peephole.zig; cause: dead-move logic duplicated vs codegen/peephole; fix: delegate to generic eliminateDeadMoves; deps: eliminate dead-move in peephole; verification: zig build test
