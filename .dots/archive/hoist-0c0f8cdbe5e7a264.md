---
title: Add TLS access comprehensive tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T11:46:25.755379+02:00\""
closed-at: "2026-01-08T13:48:09.188263+02:00"
---

File: tests/aarch64_tls.zig (new). Test LE small offset (<4096). Test LE large offset (materialization). Test IE model with relocation. Test GD model with __tls_get_addr. Verify correct relocations emitted. Dependencies: all TLS implementations. Effort: <30min
