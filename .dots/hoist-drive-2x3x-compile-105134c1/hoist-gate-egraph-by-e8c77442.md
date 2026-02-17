---
title: Gate egraph by complexity
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:07:40.585616+01:00"
---

Context: src/codegen/compile.zig:1014-1017, 1176-1253; cause: egraph optimization runs for small/simple functions where overhead dominates; fix: complexity threshold and opt-level-aware gating for egraph pass; deps: Wire release benchmark mode; verification: small-function compile latency drops with unchanged correctness tests.
