---
title: Extend x64 fp
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.342916+02:00"
---

Files: src/backends/x64/lower.isle:1-88
Root cause: no FP/SIMD lowering rules.
Fix: add f32/f64 and SIMD lowering rules and extractors.
Why: FP/SIMD parity with Cranelift.
Deps: Add x64 simd.
Verify: add FP/SIMD lower tests.
