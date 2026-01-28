---
title: Implement uload8 unsigned 8-bit load
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:26:34.180548+02:00"
closed-at: "2026-01-06T10:37:52.815019+02:00"
---

File: src/codegen/compile.zig - Add lowering for uload8. Use LDRB (load byte) which zero-extends to register width. Critical P0.
