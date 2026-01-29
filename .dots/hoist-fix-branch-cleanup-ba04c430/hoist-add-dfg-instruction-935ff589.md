---
title: Add DFG Instruction Deletion
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.407015+01:00\\\"\""
closed-at: "2026-01-29T10:28:28.452114+01:00"
close-reason: done
---

Context: src/ir/dfg.zig:263; cause: no delete/tombstone API; fix: implement removeInst and use cleanup of uses/results; deps: hoist-fix-branch-cleanup-ba04c430; verification: new DFG unit test
