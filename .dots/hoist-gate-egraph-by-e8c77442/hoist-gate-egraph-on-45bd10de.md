---
title: Gate egraph on complexity threshold
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.901636+01:00"
---

Context: src/codegen/compile.zig:1014-1017; cause: egraph cost outweighs benefit on tiny functions; fix: run egraph only when complexity and opt-level thresholds are met; deps: Add function complexity score; verification: small-benchmark optimize time drops while correctness tests pass.
