---
title: Implement TLS local-exec model
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:26:38.743450+02:00"
closed-at: "2026-01-07T06:34:09.395372+02:00"
---

File: src/backends/aarch64/lower.isle + isle_helpers.zig - Implement tls_value lowering for local-exec TLS model (simplest, executables only). Sequence: MRS x0, TPIDR_EL0 (read thread pointer), ADD x0, x0, #offset (add TLS variable offset). Need: 1) Add tls_local_exec ISLE constructor taking ExternalName, 2) Emit MRS + ADD instructions, 3) Handle symbol offset via relocation or immediate. Start with immediate offset = 0 for testing. Critical opcode for thread-local variables.
