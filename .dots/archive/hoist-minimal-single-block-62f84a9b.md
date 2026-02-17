---
title: Minimal single-block fast path
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T23:18:09.284425+01:00\\\"\""
closed-at: "2026-02-17T23:21:28.526246+01:00"
close-reason: "discarded: unstable; rerun failed gate (large(100)+6.14%)"
---

Context: one-block functions still pay computeRPO/DFS and block-label prepass in lowering. Cause: generic multi-block traversal path on single-block workload. Fix: add minimal early single-block path in lowerFunctionWithFeatures that preserves existing lowering loop logic but skips computeRPO and prepass for one-block functions only. Verify: zig build test -j1 and same-tree A/B gate with stability rerun; keep only if >=5% retained gains and no regressions.
