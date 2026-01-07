---
title: Implement splat broadcast scalar to vector
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:27:33.456800+02:00"
closed-at: "2026-01-06T20:36:48.945314+02:00"
---

File: src/codegen/compile.zig - Add lowering for splat. Use DUP instruction to broadcast scalar value to all lanes. Handle both integer and FP types. P1 operation for SIMD support.
