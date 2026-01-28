---
title: Implement uload32 unsigned 32-bit load
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:26:50.059555+02:00"
closed-at: "2026-01-06T10:37:52.830765+02:00"
---

File: src/codegen/compile.zig - Add lowering for uload32. Use LDR W-register (32-bit) which zero-extends to 64-bit. Critical P0.
