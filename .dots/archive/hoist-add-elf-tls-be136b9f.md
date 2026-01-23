---
title: Add elf_tls_get_addr libcall
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:50:32.663312+02:00\""
closed-at: "2026-01-23T23:23:37.370995+02:00"
---

In src/ir/libcall.zig:160-162, implement elf_tls_get_addr signature. Takes TLS module ID + offset, returns address. Match Cranelift. Deps: none. Verify: zig build test
