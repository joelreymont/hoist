---
title: Implement atomic operations (LL/SC fallback)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:37.460389+02:00"
closed-at: "2026-01-06T20:34:38.721195+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower atomic_rmw IR opcodes to LDXR/STXR loop sequences for non-LSE CPUs. Implement retry loop with proper memory barriers. Handle all atomic operation variants (add, sub, and, or, xor, swap). Reference: Cranelift lower.isle LL/SC patterns. Part of Phase 3 advanced features. Estimate: 2 days.
