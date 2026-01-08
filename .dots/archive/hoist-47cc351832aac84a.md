---
title: Multi-return values
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T15:24:09.942716+02:00\""
closed-at: "2026-01-08T15:14:52.452806+02:00"
---

Support multiple return values per AAPCS64. Use X0-X7, V0-V7 for returns. Handle struct returns (X8 for large structs). Generate MOV sequences for return marshaling. Test: Function returning (i64, i64, f64). Phase 1.15, Priority P0
