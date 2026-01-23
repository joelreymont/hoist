---
title: Add ir tests
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.688586+02:00\""
closed-at: "2026-01-23T20:13:50.707127+02:00"
---

Files: docs/ir.md:79-112
Root cause: no IR text round-trip tests.
Fix: add tests for parse/print round-trip and error cases.
Why: correctness of text format.
Deps: Add ir parser, Add ir printer.
Verify: zig build test.
