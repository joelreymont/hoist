---
title: Validate jump-table target labels
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:06:22.209783+01:00\""
closed-at: "2026-02-06T23:08:25.277824+01:00"
close-reason: Fail fast on invalid or unresolved jump-table labels
---

Context: /Users/joel/Work/hoist/src/machinst/buffer.zig:586; cause: emitJumpTables reads target label offsets without invalid/unbound checks; fix: reject invalid or unresolved labels before encoding offsets and add regression tests; deps: none; verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
