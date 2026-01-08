---
title: Add exception propagation test
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:08:15.247720+02:00"
---

File: tests/e2e_jit.zig. End-to-end test: call function that throws, verify exception caught in landing pad, check unwinding works correctly. Validate stack state after catch. Depends on unwind info. ~25 min.
