---
title: Generate function prologue
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.382496+02:00"
closed-at: "2026-01-07T10:45:20.739523+02:00"
---

File: src/backends/aarch64/abi.zig implement genPrologue()
Currently: Stub exists
Need: Generate stack setup and callee-save pushes
Implementation: Save FP and LR (stp x29, x30), set up frame pointer (mov x29, sp), allocate stack (sub sp, sp, #frame_size), save callee-saved registers
Dependencies: Previous emit dot (frame layout)
Estimated: 2 days
Test: Verify correct prologue for various frame sizes
