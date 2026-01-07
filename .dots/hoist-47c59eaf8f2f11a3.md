---
title: Implement Cold calling convention metadata
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:32:36.698941+02:00"
closed-at: "2026-01-07T07:47:54.811862+02:00"
---

File: src/backends/aarch64/abi.zig and src/machinst/abi.zig. Cold convention: mark function as rarely executed. Same register allocation as C, but add 'cold' attribute for backend. Use to de-prioritize inlining, register allocation pressure, code placement (move to end of function). Metadata-only change, minimal behavior change. ~10 lines. Test: verify cold function has attribute set. Depends: CallConv enum (hoist-47c59c479e51fe45).
