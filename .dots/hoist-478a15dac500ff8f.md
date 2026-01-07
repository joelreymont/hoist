---
title: "P2.4: Implement I128 rotates and extends"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:30:57.981724+02:00"
closed-at: "2026-01-04T09:02:45.374479+02:00"
---

Implement I128 rotl/rotr (2 ops) and uextend/sextend (2 ops). Rotates: combine shifts. Extends: zero/sign-extend into high part. Est: 8-16h for 4 ops. File: src/backends/aarch64/lower.isle
