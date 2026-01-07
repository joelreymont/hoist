---
title: "P3.5: Add multiply overflow operations"
status: closed
priority: 3
issue-type: task
created-at: "2026-01-04T12:55:45.392806+02:00"
closed-at: "2026-01-04T13:06:45.161127+02:00"
---

HIGH PRIORITY - Bounds checking, security-critical. Add 6 ops: umul_overflow, smul_overflow for I16/I32/I64. Rust's checked arithmetic needs this. Cranelift ref: lower.isle lines 3104, 3120, 3134, 3152, 3168, 3182. Files: src/backends/aarch64/lower.isle. Est: 1-2 days.
