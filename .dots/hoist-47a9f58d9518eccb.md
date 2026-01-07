---
title: Implement TLS (thread-local storage) access
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:35.005732+02:00"
closed-at: "2026-01-07T06:26:17.294979+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcode: tls_value. Instructions: MRS (read TPIDR_EL0 thread pointer register) + LDR (load from TLS offset). Pattern depends on TLS model (local-exec, initial-exec, etc.). Dependencies: TLS model selection (can start with local-exec). Effort: 1 day.
