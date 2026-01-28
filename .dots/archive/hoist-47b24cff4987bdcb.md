---
title: Add uadd_overflow_cin lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.813649+02:00"
closed-at: "2026-01-06T08:44:46.408190+02:00"
---

File: compile.zig. Lower uadd_overflow_cin. Identical to sadd_overflow_cin but unsigned semantics. Reuse ADDS+ADCS infrastructure. Depends on: ADCS instruction variant. ARM64: ADDS+ADCS. Effort: 15 min.
