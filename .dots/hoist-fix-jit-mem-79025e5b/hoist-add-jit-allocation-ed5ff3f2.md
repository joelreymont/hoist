---
title: Add JIT Allocation Tests
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.339729+01:00\\\"\""
closed-at: "2026-01-29T10:16:55.873004+01:00"
close-reason: done
---

Context: tests/e2e_jit.zig:1; cause: no coverage for overlapping blobs/overflow; fix: add tests for distinct blobs and expected failure on overflow; deps: hoist-fix-jit-definefunction-3ff23b0c; verification: zig build test
