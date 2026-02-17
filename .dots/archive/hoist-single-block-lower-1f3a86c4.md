---
title: Single-block lower fast path
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:18:12.616458+01:00\\\"\""
closed-at: "2026-02-17T22:22:03.960061+01:00"
close-reason: "discarded: failed gate (large(1000)+5.22%, parallel batch+5.25%)"
---

Context: src/machinst/lower.zig lowerFunctionWithFeatures always computes RPO via DFS+hash maps and prepopulates block_map even for single-block functions. Cause: generic CFG path on hot single-block benchmark workloads. Fix: detect single-block layout and lower directly without computeRPO/prepopulation while preserving branch semantics. Verify: zig build test -j1 plus same-tree A/B gate; keep only if >=5% retained gains with no regressions.
