---
title: Add vany_true lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:04:44.329344+02:00\""
closed-at: "2026-01-23T14:58:46.719809+02:00"
---

Files: src/backends/aarch64/isle_impl.zig, src/generated/aarch64_lower.isle
What: Implement vany_true - check if any vector lane is non-zero
Pattern: UMAXV to find maximum, then compare to zero
Verification: Add test in tests/simd_ops.zig
