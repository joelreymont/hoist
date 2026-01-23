---
title: Fix aarch64_tls test - tls_value opcode not implemented in lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-23T09:17:19.340748+02:00\""
closed-at: "2026-01-23T09:22:51.818744+02:00"
---

tests/aarch64_tls.zig:30 uses tls_value opcode. Lowering in compile.zig:1584 returns LoweringFailed. Need to implement tls_value lowering for Local-Exec TLS model.
