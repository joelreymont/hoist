---
title: Implement try_call/try_call_indirect for exception handling
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:43.316786+02:00"
closed-at: "2026-01-07T06:30:32.490365+02:00"
---

File: src/codegen/lower_aarch64.zig. Opcodes: try_call, try_call_indirect. Lower to BL/BLR with exception table integration. Required for WebAssembly exception handling proposal. Instruction sequence same as regular call but register exception handler metadata (landing pad offset, action table). Dependencies: exception table infrastructure. Effort: 2-3 days.
