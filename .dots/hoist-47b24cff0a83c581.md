---
title: Add uload16x4/sload16x4 lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.797518+02:00"
closed-at: "2026-01-06T21:09:20.053919+02:00"
---

File: compile.zig. Lower both opcodes to LD1 {v.4h}, [addr] + USHLL/SSHLL v.4s, v.4h, #0. Reuse vector load+widen infrastructure from uload8x8. Depends on: uload8x8/sload8x8 infrastructure. ARM64: LD1+USHLL/SSHLL with .4H→.4S. Effort: 20 min.
