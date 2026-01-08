---
title: Wire try_call exception edge
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:07:51.101585+02:00"
---

File: src/ir/builder.zig. When creating try_call instruction, add exception_successor parameter. Connect to landing pad block in CFG. Update instruction builder API. Depends on hoist-e597305b39969ff1. ~15 min.
