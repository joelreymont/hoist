---
title: Lexer parseInt error
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:24:41.398048+01:00\""
closed-at: "2026-02-01T14:25:33.012356+01:00"
close-reason: completed
---

src/dsl/isle/lexer.zig:198 cause: parseInt errors mapped to InvalidInteger via catch return; fix: propagate parseInt errors with try and add invalid integer test; why: avoid error masking, keep error detail.
