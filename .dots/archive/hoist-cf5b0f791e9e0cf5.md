---
title: Add TLS General Dynamic TLSDESC sequence
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T12:45:12.979395+02:00\""
closed-at: "2026-01-08T13:26:20.970147+02:00"
---

File: src/backends/aarch64/inst.zig,emit.zig - Add ADRP + LDR + ADD + BLR (descriptor call) sequence. Emit relocs: aarch64_tlsdesc_adr_page21, aarch64_tlsdesc_ld64_lo12, aarch64_tlsdesc_add_lo12, aarch64_tlsdesc_call. Depends on: none. Enables: full dynamic TLS.
