---
title: Update ENode Const Payload
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.368500+01:00\\\"\""
closed-at: "2026-01-29T10:22:46.348363+01:00"
close-reason: done
---

Context: src/ir/egraph.zig:29; cause: no const value storage; fix: add optional imm field and update hash/eql/free; deps: hoist-fix-egraph-constants-bfbdb0b3; verification: compile + egraph tests pass
