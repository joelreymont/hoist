---
title: Verify external name loading implementation
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T22:28:30.293193+02:00"
---

Files: src/backends/aarch64/{inst.zig,emit.zig,isle_impl.zig} - CRITICAL: Verify that external function calls work in PIC mode. Need LoadExtNameGot (ADRP+LDR from GOT) and proper relocations (R_AARCH64_ADR_GOT_PAGE, R_AARCH64_LD64_GOT_LO12_NC). If missing, this blocks calling any external functions in PIC code. Test with simple external call and verify GOT access.
