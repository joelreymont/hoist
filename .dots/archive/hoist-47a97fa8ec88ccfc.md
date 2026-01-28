---
title: Implement atomic operations (LSE path)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T21:59:37.086097+02:00"
closed-at: "2026-01-06T20:27:49.913600+02:00"
---

File: src/codegen/lower_aarch64.zig. Lower atomic_rmw IR opcodes to LSE atomic instructions (LDADD, LDCLR, etc.). Implement fence → DMB variants. Implement atomic_cas → CAS instruction. Requires LSE CPU feature detection. Reference: Cranelift lower.isle atomic patterns. Part of Phase 3 advanced features. Estimate: 2 days.
