---
title: "P2.5.14: Add vconst pattern"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T13:21:28.756488+02:00"
closed-at: "2026-01-04T13:34:26.463738+02:00"
---

File: src/backends/aarch64/lower.isle - Add 1 rule for vconst using load_const128 with u128_from_constant extractor. Uses ty_vec128 extractor. Cranelift:2303. Depends on P2.5.1.
