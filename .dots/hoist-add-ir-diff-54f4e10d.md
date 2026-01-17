---
title: Add IR diff testing
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:06:33.113572+02:00"
---

Files: tests/diff_cranelift.zig (new)
What: Compare Hoist IR output against Cranelift for same input
Method: Parse CLIF text, compile with both, compare IR dumps
Coverage: All opcodes in /tmp/handled_opcodes.txt
Verification: Zero diff on supported opcodes
