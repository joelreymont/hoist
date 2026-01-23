---
title: Wire ldxr/stxr emit
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-14T14:14:12.367680+02:00\\\"\""
closed-at: "2026-01-14T14:15:14.565485+02:00"
close-reason: emit switch handles ldxr/stxr sizes
---

File: src/backends/aarch64/emit.zig:120. Root cause: Inst .ldxr/.stxr variants unhandled in emit switch, leading to panic. Fix: add switch cases to dispatch size32/size64 to emitLdxrW/X and emitStxrW/X. Why: unblock exclusive access tests and correct atomic lowering.
