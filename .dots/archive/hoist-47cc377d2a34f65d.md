---
title: global_value implementation
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T15:24:50.114112+02:00\""
closed-at: "2026-01-07T23:44:57.998823+02:00"
---

Add GlobalValue resolution to Function. Implement symbol resolution. Generate ADRP + ADD/LDR for GOT access. Handle PIC/PIE requirements. Test: Load global variable address. File: isle_impl.zig:1045. Phase 2.6, Priority P1
