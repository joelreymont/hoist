---
title: Hoist next single-thread perf
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T18:21:36.844778+01:00\""
closed-at: "2026-02-17T18:39:02.896555+01:00"
close-reason: completed
---

Full context: post-improvement baseline /tmp/hoist-d3-after.log still shows large(5000) dominated by lower+emit+regalloc in bench/compile_large.zig; objective is additional >=5% retained gains with no perf regressions; each child dot requires zig build test + same-tree A/B bench-compare proof and keep/discard decision.
