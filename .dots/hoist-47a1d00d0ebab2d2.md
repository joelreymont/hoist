---
title: Add vcode field to Context
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T12:49:26.087368+02:00"
closed-at: "2026-01-05T12:58:25.807202+02:00"
---

File: src/codegen/context.zig:16 - Context missing vcode field. compile.zig needs it for regalloc. Fix: Add vcode: ?*VCode field. Blocks: test compilation.
