---
title: Add ir printer
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.676594+02:00"
---

Files: docs/ir.md:79-112, src/ir/function.zig:1-80
Root cause: no IR text serializer.
Fix: add src/ir/text/printer.zig to emit IR text format.
Why: CLIF round-trip and debugging.
Deps: Add ir parser.
Verify: round-trip tests.
