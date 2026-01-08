---
title: Implement tail call argument marshaling
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T12:45:34.478167+02:00\""
closed-at: "2026-01-08T15:14:19.001061+02:00"
---

File: src/backends/aarch64/isle_impl.zig - For return_call, marshal arguments to ABI locations like regular call. BUT: reuse current frame (no new SP adjustment). Check caller/callee frame compatibility. Depends on: return_call opcode. Enables: argument setup for tail calls.
