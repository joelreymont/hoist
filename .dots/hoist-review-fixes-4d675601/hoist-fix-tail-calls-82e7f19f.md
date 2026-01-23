---
title: Fix tail calls
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-17T12:48:35.251387+02:00\\\"\""
closed-at: "2026-01-23T07:13:54.484657+02:00"
---

Files: tests/e2e_tail_calls.zig, build.zig:189-201. Cause: API drift (iconst/fconst). Fix: update APIs, re-enable. Why: tail-call coverage. Verify: zig build test.
