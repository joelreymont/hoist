---
title: CFG liveness bitset 1
status: open
priority: 1
issue-type: task
created-at: "2026-02-21T19:21:15.560728+01:00"
blocks:
  - hoist-out-stack-lazy-92cf6490
---

Context: src/regalloc/liveness.zig:330-472; cause: AutoHashMap fixed-point set churn; fix: introduce dense bitset live-in/out representation with worklist; deps:hoist-out-stack-lazy-92cf6490; verification: liveness tests + bench gate.
