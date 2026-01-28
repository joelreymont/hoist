---
title: Generate function epilogue
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.387887+02:00"
closed-at: "2026-01-07T10:45:20.745158+02:00"
---

File: src/backends/aarch64/abi.zig implement genEpilogue()
Mirror of prologue: restore registers, deallocate stack, return
Implementation: Restore callee-saved, deallocate stack (add sp, sp, #frame_size), restore FP and LR (ldp x29, x30), return (ret)
Dependencies: Previous emit dot
Estimated: 1 day
Test: Verify epilogue matches prologue
