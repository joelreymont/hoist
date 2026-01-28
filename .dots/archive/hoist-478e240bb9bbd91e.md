---
title: "P2.5.11: Add uunarrow patterns"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T13:21:15.940297+02:00"
closed-at: "2026-01-04T13:33:55.519537+02:00"
---

File: src/backends/aarch64/lower.isle - Add 2 rules for unsigned/unsigned narrowing: sqxtun (prio 1) and xtn (prio 0). Uses ty_vec128_int extractor. Cranelift:2468,2476. Depends on P2.5.2.
