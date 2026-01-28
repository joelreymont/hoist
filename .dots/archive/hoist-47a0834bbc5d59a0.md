---
title: Add special x64 instructions (~200 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:16:23.382119+02:00"
closed-at: "2026-01-05T13:15:31.732446+02:00"
---

File: src/backends/x64/inst.zig - Port cvt*, set*, cmov*, bswap, popcnt, etc. to Inst enum. Depends on: hoist-47a0830486134cd2 (load/store). Needed by: specialized lowering. Est: 25 min.
