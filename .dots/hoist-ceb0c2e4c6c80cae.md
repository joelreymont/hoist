---
title: Move reload to dominator
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:05:42.170076+02:00"
---

File: src/codegen/compile.zig. In emitReloads(), if reload marked as hoistable, emit in dominating block instead of use block. Update liveness to reflect hoisted reload. Remove original reload location. ~20 min.
