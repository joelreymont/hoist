---
title: Audit Struct ExpectEqual Usage
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T10:05:45.585287+01:00\""
closed-at: "2026-01-31T20:59:00.293391+01:00"
---

Context: repo-wide tests; cause: struct expectEqual uses remain; fix: convert to ohsnap where structs compared; deps: hoist-fix-struct-expectequal-a31acbda; verification: rg expectEqual on structs returns none
