---
title: Add ISLE coverage for shift ops
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-27T20:12:36.210301+01:00\""
closed-at: "2026-01-27T20:19:24.990034+01:00"
---

File: tests/isle_coverage.zig
Add tests for: ishl, ushr, sshr, rotr, rotl
Pattern: Copy existing iadd test, change opcode to shift op.
Verify coverage tracker records shift-related rules.
~15 min task.
