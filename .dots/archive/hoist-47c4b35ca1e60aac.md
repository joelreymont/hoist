---
title: Implement try_call exception handling opcode
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T06:26:48.618485+02:00"
closed-at: "2026-01-07T07:19:28.347030+02:00"
---

File: src/backends/aarch64/lower.isle - Add lowering for try_call opcode (function call that can throw exception). Instruction: BL <target> followed by branch to landing pad on exception. Need: 1) ISLE rule matching (try_call func args landing_pad), 2) Emit call instruction, 3) Wire exception edge to landing_pad block, 4) Mark as call with exception semantics. Dependencies: exception landing pad infrastructure (hoist-47b24cffbd574f2e). Critical for exception-aware code generation.
