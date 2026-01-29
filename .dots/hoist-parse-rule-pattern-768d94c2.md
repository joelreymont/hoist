---
title: Parse rule/pattern/expr
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T20:15:59.813324+01:00"
---

Full context: src/dsl/isle/parser.zig:306/366/398 missing rule priority, @ bind, _, ints/bools, let expr. Cause: limited grammar. Fix: add priority parsing, pattern atoms (wildcard/const/bind), let/const expr parsing. Why: parse lowering rules.
