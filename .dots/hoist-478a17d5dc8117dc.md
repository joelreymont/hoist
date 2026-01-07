---
title: "P2.11: Implement missing vector operations"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:31:31.214478+02:00"
closed-at: "2026-01-04T09:12:18.680567+02:00"
---

Implement ~90 missing vector operation rules. This is the long tail - vector widening ops, vector shuffles, vector compares, etc. Audit Cranelift to identify specific ops. Est: 90-180h. File: src/backends/aarch64/lower.isle. Start after critical ops done.
