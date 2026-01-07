---
title: "P3.1: Implement extending load operations (uload/sload)"
status: closed
priority: 3
issue-type: task
created-at: "2026-01-04T12:55:43.902928+02:00"
closed-at: "2026-01-04T13:00:41.910153+02:00"
---

CRITICAL PRIORITY - 20-30% perf loss without this. Implement 14 extending load rules: uload8/16/32/64 and sload8/16/32. Map to LDRB/LDRH/LDR with sign/zero extension. Cranelift ref: lower.isle lines 1284-1286, 1343-1345, 2641-2644. Files: src/backends/aarch64/lower.isle, isle_helpers.zig. Est: 2-3 days.
