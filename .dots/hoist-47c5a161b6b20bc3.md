---
title: Implement IR builder API
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T07:33:21.928896+02:00"
closed-at: "2026-01-07T07:45:29.893645+02:00"
---

File: src/ir/builder.zig (expand existing). Add fluent API for building IR: bb.iadd(x, y), bb.icmp(.slt, x, y), bb.br(target_bb). Methods for all opcodes. Return Value handles. ~300 lines of builder methods. Required for e2e tests to construct IR programmatically. Unblocks: all e2e tests.
