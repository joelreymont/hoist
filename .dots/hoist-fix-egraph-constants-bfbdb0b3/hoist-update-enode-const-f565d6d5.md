---
title: Update ENode Const Payload
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.368500+01:00"
---

Context: src/ir/egraph.zig:29; cause: no const value storage; fix: add optional imm field and update hash/eql/free; deps: hoist-fix-egraph-constants-bfbdb0b3; verification: compile + egraph tests pass
