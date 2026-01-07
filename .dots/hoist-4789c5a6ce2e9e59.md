---
title: "T2.1c: Implement EON fusions"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:08:32.398907+02:00"
closed-at: "2026-01-04T08:14:09.377811+02:00"
---

Files: src/backends/aarch64/lower.isle, isle_helpers.zig. Implement bxor+bnot fusion (EON instruction). 6 rules: scalar, NOT(XOR) pattern, I128, vectors. 6-12h.
