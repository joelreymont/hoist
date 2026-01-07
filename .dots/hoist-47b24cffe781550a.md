---
title: Add try_call_indirect lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.854090+02:00"
closed-at: "2026-01-07T06:30:32.510290+02:00"
---

File: compile.zig. Lower try_call_indirect to BLR instruction with exception handling. Reuse try_call exception infrastructure, use BLR instead of BL. Extract function pointer, emit BLR, wire exception edges. Depends on: try_call infrastructure. ARM64: BLR with exception edges. Effort: 30 min.
