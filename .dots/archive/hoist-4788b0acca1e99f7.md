---
title: "Dot 4.6: Implement stack_addr opcode"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T06:51:05.502252+02:00"
closed-at: "2026-01-04T06:57:12.269600+02:00"
---

Files: lower.isle:450, isle_helpers.zig:2180. Rule for stack slot address. Helper: aarch64_stack_addr - emit ADD Xd, SP, #offset. Test: stack address calc. 25min
