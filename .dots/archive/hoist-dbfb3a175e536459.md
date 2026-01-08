---
title: Emit STP for adjacent spills
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T20:05:07.616967+02:00\""
closed-at: "2026-01-08T21:07:02.101750+02:00"
---

File: src/codegen/compile.zig. In emitSpills(), check SpillSlotMap for adjacent pairs. If found and 8-byte aligned, emit single STP instead of two STR. Track already-emitted spills to avoid duplicates. ~25 min.
