---
title: Add usub_overflow_bin lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.824723+02:00"
closed-at: "2026-01-06T08:47:32.104656+02:00"
---

File: compile.zig. Lower usub_overflow_bin. Identical to ssub_overflow_bin but unsigned semantics. Reuse SUBS+SBCS infrastructure. Depends on: SBCS instruction variant. ARM64: SUBS+SBCS. Effort: 15 min.
