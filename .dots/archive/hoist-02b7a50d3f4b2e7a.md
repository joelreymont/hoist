---
title: Add unwind info generation
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T20:08:01.730792+02:00\""
closed-at: "2026-01-08T21:18:26.522621+02:00"
---

File: src/backends/aarch64/unwind.zig (new). Generate DWARF unwind info for exception handling. Map IP ranges to landing pads. Encode CFA (Canonical Frame Address) for stack unwinding. Reference DWARF 4 spec. ~30 min.
