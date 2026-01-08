---
title: Add try_call opcode
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T21:18:59.664460+02:00\""
closed-at: "2026-01-08T21:22:35.378494+02:00"
---

File: src/ir/opcodes.zig. Add try_call to Opcode enum after landingpad. try_call is like call but with exception handling - branches to landing pad on exception. ~5 min.
