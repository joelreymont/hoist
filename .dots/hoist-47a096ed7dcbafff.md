---
title: Wire unwind to backends (~80 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:21:52.750042+02:00"
closed-at: "2026-01-05T13:15:36.420110+02:00"
---

File: src/isa/unwind.zig. Connect unwind info generation to x64/aarch64 prologues. Emit directives during lowering. Depends on: DWARF writer, Windows writer, stack maps. Est: 20 min.
