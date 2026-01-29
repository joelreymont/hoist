---
title: Sema let/and/wild
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T20:16:11.643065+01:00\""
closed-at: "2026-01-29T20:40:11.863262+01:00"
close-reason: completed
---

Full context: src/dsl/isle/sema.zig:669/772 missing wildcard/bind/and/let handling. Cause: checkPattern/checkExpr only handle var/term/const. Fix: implement wildcard/bind/and and let expr typing. Why: support core rule syntax.
