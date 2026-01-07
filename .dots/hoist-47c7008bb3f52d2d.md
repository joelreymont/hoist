---
title: Implement end-to-end compile() entry point
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:11:33.483521+02:00"
closed-at: "2026-01-07T14:26:27.715295+02:00"
---

File: src/machinst/compile.zig (new file)
Implementation: Create ABI, compute block ordering, lower IR → VCode, register allocation, compute frame layout, emit machine code
Dependencies: All previous phases
Estimated: 3 days
Test: End-to-end compile simple function
