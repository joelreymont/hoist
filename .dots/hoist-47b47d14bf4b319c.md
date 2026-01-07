---
title: Implement stack probe for large frames
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:06:18.461013+02:00"
closed-at: "2026-01-07T06:30:27.181746+02:00"
---

File: src/backends/aarch64/abi.zig - In emitPrologue: if layout.needs_stack_probe, emit probe loop. Loop: SUB sp, sp, #4096; STR xzr, [sp] (touch page to trigger guard); repeat while remaining>4096. Final SUB for remainder. Dependencies: hoist-47b47c0bd288f9c1, hoist-47b46201fe9355b0.
