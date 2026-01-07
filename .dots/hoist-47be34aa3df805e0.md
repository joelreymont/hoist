---
title: Add liveness analysis tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T22:41:53.194504+02:00"
closed-at: "2026-01-06T22:44:03.035221+02:00"
---

File: src/regalloc/liveness.zig - Add tests for computeLiveness with mock instructions. Test: 1) Simple def-use patterns, 2) Multiple vregs with overlapping ranges, 3) Use-before-def (parameters), 4) Multiple uses extending range, 5) Different register classes
