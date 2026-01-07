---
title: "P2.5.10: Add unarrow patterns"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T13:21:11.661317+02:00"
closed-at: "2026-01-04T13:33:55.515487+02:00"
---

File: src/backends/aarch64/lower.isle - Add 2 rules for unsigned narrowing: uqxtn (prio 1) and xtn (prio 0). Uses ty_vec128_int extractor. Cranelift:2452,2460. Depends on P2.5.2.
