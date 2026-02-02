---
title: Add dotprod patterns
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.813315+01:00"
blocks:
  - hoist-detect-aarch64-features-a0643e73
---

Context: src/backends/aarch64/lower.isle: vector shuffle rules; cause: FEAT_DotProd patterns pending; fix: add SDOT/UDOT ISLE rules gated by isa.features.has_dotprod; deps: detectNative dotprod flag; verification: new lowering tests in tests/ for dotprod IR.
