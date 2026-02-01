---
title: Mem alloc overflow
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:16:24.697845+01:00\""
closed-at: "2026-02-01T14:16:47.789785+01:00"
close-reason: completed
---

src/jit/memory.zig:72 cause: overflow from std.math.add masked as OutOfMemory; fix: propagate error.Overflow via try std.math.add and add overflow expectation in test; why: no error masking, correct overflow reporting.
