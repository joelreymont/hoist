---
title: Add select_spectre_guard
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:05:34.778892+02:00\""
closed-at: "2026-01-23T14:58:10.367181+02:00"
---

Files: src/backends/aarch64/isle_impl.zig
What: Implement Spectre mitigation select
Pattern: CSEL with speculation barrier (CSDB)
Purpose: Prevent speculative execution past bounds checks
Verification: Verify CSDB emitted after CSEL
