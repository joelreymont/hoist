---
title: Add vhigh_bits lowering
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:04:41.840558+02:00"
---

Files: src/backends/aarch64/isle_impl.zig, src/generated/aarch64_lower.isle
What: Implement vhigh_bits extractor - extract sign bits from vector lanes to GPR
Pattern: UMOV + shifts to collect MSBs from each lane
Verification: Add test in tests/simd_ops.zig
