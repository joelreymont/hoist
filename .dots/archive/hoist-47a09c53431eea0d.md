---
title: Add call lowering (~150 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:23:23.305767+02:00"
closed-at: "2026-01-05T13:15:49.176100+02:00"
---

File: src/abi/call_lowering.zig. Lower call instruction: marshal args, emit call, unmarshal returns. Handle tail calls. Depends on: prologue, epilogue. Est: 35 min.
