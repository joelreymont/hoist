---
title: Wire try_call exception edges
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.850486+02:00"
closed-at: "2026-01-07T06:30:32.505684+02:00"
---

File: compile.zig. Connect exception handler blocks. After BL, check for exception (compare exception reg), branch to landing pad if exception occurred. Use existing branch infrastructure. Depends on: try_call basic lowering. Effort: 30 min.
