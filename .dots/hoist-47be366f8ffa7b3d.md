---
title: Implement AArch64 ABI argument classification
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:42:22.903304+02:00"
closed-at: "2026-01-06T22:57:52.861851+02:00"
---

File: src/backends/aarch64/abi.zig (new) - Implement AArch64 calling convention. Need: 1) ArgLocation enum (Reg/Stack), 2) classifyArgs() returning []ArgLocation for function signature, 3) Integer args in X0-X7 then stack, 4) FP args in V0-V7 then stack, 5) Large types on stack, 6) Stack slots 8-byte aligned
