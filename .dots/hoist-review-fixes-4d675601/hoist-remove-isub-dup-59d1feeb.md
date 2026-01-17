---
title: Remove isub dup
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-17T12:46:36.954848+02:00\\\"\""
closed-at: "2026-01-17T13:11:59.559842+02:00"
---

Files: src/codegen/compile.zig:1726-1785. Cause: duplicate .isub lowering block. Fix: remove duplicate; keep single path and/or factor helper. Why: avoid divergence. Verify: zig build test.
