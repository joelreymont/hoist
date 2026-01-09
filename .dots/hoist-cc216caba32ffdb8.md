---
title: Add algebraic rewrite rules
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T07:46:07.343774+02:00"
---

Define rewrite rules: (x + 0) → x, (x * 1) → x, (x - x) → 0, strength reduction, etc. Store as pattern-action pairs. Files: src/ir/egraph_rules.zig (new), ~500 lines. Comprehensive rule set. ~180 min.
