---
title: "T2.1b: Implement ORN fusions"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:08:32.394731+02:00"
closed-at: "2026-01-04T08:14:09.371121+02:00"
---

Files: src/backends/aarch64/lower.isle, isle_helpers.zig. Implement bor+bnot fusion (ORN instruction). 7 rules: scalar variants, I128, vectors. Pattern similar to BIC. 7-14h.
