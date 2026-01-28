---
title: Add uload8x8 lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.789377+02:00"
closed-at: "2026-01-06T21:09:19.310975+02:00"
---

File: compile.zig. Lower uload8x8 opcode. Extract address, call LD1+USHLL helper, emit sequence. Depends on: LD1+USHLL infrastructure. ARM64: LD1+USHLL. Effort: 15 min.
