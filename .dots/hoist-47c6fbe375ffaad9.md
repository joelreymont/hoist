---
title: Create MachineEnv for ARM64
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.348746+02:00"
closed-at: "2026-01-07T10:42:57.185894+02:00"
---

File: src/backends/aarch64/machine_env.zig (new file)
Need: Define allocatable registers, reserved registers, stack slots
Implementation: allocatableRegs(class) returns x0-x27 (excluding x18/x29/x30/x31) for int, v0-v31 for float
Dependencies: None
Estimated: 1 day
Test: Verify correct registers returned
