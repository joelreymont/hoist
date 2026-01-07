---
title: Wire ABI to calling conventions (~70 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:20:44.044273+02:00"
closed-at: "2026-01-05T13:15:36.392469+02:00"
---

File: src/backend/x64/abi.zig. Connect all ABI pieces to System V, Windows fastcall conventions. Handle return values, callee-saved regs. Depends on: stack args, varargs, probestack, unwind. Est: 20 min.
