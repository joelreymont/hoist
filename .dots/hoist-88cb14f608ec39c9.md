---
title: Implement TLS access sequences
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T22:28:37.158220+02:00"
---

Files: src/backends/aarch64/{inst.zig,isle_impl.zig,emit.zig} - Add thread-local storage access. ELF TLSDESC model: ADRP + LDR + ADD + BLR sequence to call TLS descriptor. MachO: different model with ADRP + LDR from TLS GOT. Handle all TLS models: General Dynamic, Local Dynamic, Initial Exec, Local Exec. Depends on hoist-8024f229ae156faf for GOT access.
