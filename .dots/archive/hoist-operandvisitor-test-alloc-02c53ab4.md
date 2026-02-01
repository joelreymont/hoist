---
title: OperandVisitor test alloc
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:19:04.668971+01:00\""
closed-at: "2026-02-01T14:19:35.618352+01:00"
close-reason: completed
---

src/machinst/machinst.zig:207 cause: append uses catch unreachable in test helper; fix: pre-allocate capacity with try and use appendAssumeCapacity; why: remove error masking, keep test infallible.
