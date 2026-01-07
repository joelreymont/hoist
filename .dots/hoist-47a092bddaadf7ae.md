---
title: Add stack argument passing (~100 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:20:42.519221+02:00"
closed-at: "2026-01-05T13:15:49.106070+02:00"
---

File: src/backend/x64/abi_stack.zig. Implement stack argument layout, compute offsets for args that don't fit in registers. Handle alignment, struct passing. Est: 25 min.
