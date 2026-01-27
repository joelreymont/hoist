---
title: Add unwind info emission for AArch64
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-27T20:14:23.907800+01:00\""
closed-at: "2026-01-27T20:27:14.392765+01:00"
---

File: src/backends/aarch64/emit.zig or new unwind.zig
Generate .eh_frame or ARM exception tables for try_call.
Track: call sites, landing pads, cleanup actions.
Start with: just generate call site table mapping PC -> landing_pad.
~30 min task.
