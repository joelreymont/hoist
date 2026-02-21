---
title: CFG liveness bitset 1
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.560728+01:00\\\"\""
closed-at: "2026-02-21T19:46:58.542369+01:00"
close-reason: "completed: repeat-9 gate pass (/tmp/hoist-cfglive-parent-vs-cand-r9.md)"
blocks:
  - hoist-out-stack-lazy-92cf6490
---

Context: src/regalloc/liveness.zig:330-472; cause: AutoHashMap fixed-point set churn; fix: introduce dense bitset live-in/out representation with worklist; deps:hoist-out-stack-lazy-92cf6490; verification: liveness tests + bench gate.
