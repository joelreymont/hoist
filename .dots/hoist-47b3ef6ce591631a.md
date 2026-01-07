---
title: Implement uload16 unsigned 16-bit load
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:26:41.873304+02:00"
closed-at: "2026-01-06T10:37:52.823403+02:00"
---

File: src/codegen/compile.zig - Add lowering for uload16. Use LDRH (load halfword) which zero-extends. Critical P0.
