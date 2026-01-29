---
title: Add dotprod patterns
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T23:31:30.789323+01:00"
---

Context: src/backends/aarch64/lower.isle: vector shuffle rules; cause: FEAT_DotProd patterns pending; fix: add SDOT/UDOT ISLE rules gated by isa.features.has_dotprod; deps: detectNative dotprod flag; verification: new lowering tests in tests/ for dotprod IR.
