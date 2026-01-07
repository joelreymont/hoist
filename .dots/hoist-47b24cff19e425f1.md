---
title: Add uload32x2/sload32x2 lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.801457+02:00"
closed-at: "2026-01-06T21:09:20.425230+02:00"
---

File: compile.zig. Lower both opcodes to LD1 {v.2s}, [addr] + USHLL/SSHLL v.2d, v.2s, #0. Reuse vector load+widen infrastructure from uload8x8. Depends on: uload8x8/sload8x8 infrastructure. ARM64: LD1+USHLL/SSHLL with .2S→.2D. Effort: 20 min.
