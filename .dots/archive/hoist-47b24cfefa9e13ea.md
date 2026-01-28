---
title: Add sload8x8 lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.793451+02:00"
closed-at: "2026-01-06T21:09:19.682333+02:00"
---

File: compile.zig. Lower sload8x8 opcode. Same as uload8x8 but use SSHLL instead of USHLL. Reuse infrastructure. Depends on: LD1+USHLL infrastructure. ARM64: LD1+SSHLL. Effort: 10 min.
