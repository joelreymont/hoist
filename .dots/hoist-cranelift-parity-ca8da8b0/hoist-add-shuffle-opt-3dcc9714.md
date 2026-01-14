---
title: Add shuffle opt
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.805519+02:00"
---

Files: docs/feature_gap_analysis.md:103-107
Root cause: vector shuffle optimization missing.
Fix: add shuffle pattern matching in SIMD lowering/opts.
Why: SIMD performance parity.
Deps: Add x64 simd, aarch64 SIMD rules.
Verify: SIMD optimization tests.
