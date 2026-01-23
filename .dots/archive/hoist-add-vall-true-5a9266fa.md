---
title: Add vall_true lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:04:43.248851+02:00\""
closed-at: "2026-01-23T14:58:42.774932+02:00"
---

Files: src/backends/aarch64/isle_impl.zig, src/generated/aarch64_lower.isle
What: Implement vall_true - check if all vector lanes are non-zero
Pattern: UMINV to find minimum, then compare to zero
Verification: Add test in tests/simd_ops.zig
