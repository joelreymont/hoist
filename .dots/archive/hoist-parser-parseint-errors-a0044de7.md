---
title: Parser parseInt errors
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:31:16.399633+01:00\""
closed-at: "2026-02-01T14:32:18.403958+01:00"
close-reason: completed
---

src/ir/text/parser.zig:111 cause: parseInt errors mapped to UnexpectedToken via catch return; fix: add InvalidCharacter/Overflow to ParseError, use try parseInt, add invalid literal test; why: avoid masking parse errors.
