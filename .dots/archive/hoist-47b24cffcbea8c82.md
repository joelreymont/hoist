---
title: Add try_call basic lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.847027+02:00"
closed-at: "2026-01-07T06:30:32.500547+02:00"
---

File: compile.zig. Lower try_call to BL instruction (without exception handling for now). Emit BL, track return values via try_call_ret block args. Depends on: exception landing pad infrastructure. ARM64: BL. Effort: 20 min.
