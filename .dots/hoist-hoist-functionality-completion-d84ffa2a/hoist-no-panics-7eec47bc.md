---
title: No panics
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-29T12:35:40.621013+01:00\\\"\""
closed-at: "2026-01-29T13:17:53.288809+01:00"
close-reason: completed
---

File: src/jit/module.zig:224; cause: @panic/unreachable still present; fix: replace with error unions and explicit handling; why: correctness and no error masking.
