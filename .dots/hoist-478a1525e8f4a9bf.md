---
title: "P2.2: Implement I128 bitwise operations"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:30:46.128905+02:00"
closed-at: "2026-01-04T08:44:41.474164+02:00"
---

Implement I128 band/bor/bxor/bnot operations. Simple since no carry: just operate on low and high parts separately. Include bitwise fusion patterns (BIC/ORN/EON). Est: 10-20h for 4 base ops + fusions. File: src/backends/aarch64/lower.isle
