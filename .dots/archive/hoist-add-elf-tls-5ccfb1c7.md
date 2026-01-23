---
title: Add elf_tls_get_offset libcall
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:50:32.668951+02:00\""
closed-at: "2026-01-23T23:24:32.364871+02:00"
---

In src/ir/libcall.zig:160-162, implement elf_tls_get_offset signature. Returns TLS offset from thread pointer. Match Cranelift. Deps: none. Verify: zig build test
