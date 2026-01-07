---
title: Add exception landing pad infrastructure
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.843296+02:00"
closed-at: "2026-01-07T06:30:32.495410+02:00"
---

File: src/ir/cfg.zig. Add support for exception edges in CFG. Extend successor tracking to include exception edges. Add eh_label field to Block for exception handler targets. Required for try_call/try_call_indirect. COMPLEX. Effort: 30 min.
