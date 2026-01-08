---
title: Emit spill/reload for AArch64
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T11:46:25.562562+02:00"
---

File: src/backends/aarch64/isa.zig, insertSpillReloads(). Update to use real offsets from frame computation. Handle different value sizes (8, 16, 32, 64-bit). Respect alignment requirements. Add e2e test verifying LDR/STR generated. Dependencies: frame size connection. Effort: <30min
