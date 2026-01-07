---
title: Multi-return values
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:09.942716+02:00"
---

Support multiple return values per AAPCS64. Use X0-X7, V0-V7 for returns. Handle struct returns (X8 for large structs). Generate MOV sequences for return marshaling. Test: Function returning (i64, i64, f64). Phase 1.15, Priority P0
