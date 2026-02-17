---
title: Lazy CFG+domtree build
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:37:40.069681+01:00\\\"\""
closed-at: "2026-02-17T22:40:12.211295+01:00"
close-reason: "discarded: failed gate (large(100)+35.96%, parallel batch+6.12%)"
---

Context: optimize currently computes CFG and dominator tree eagerly before pass gating. Cause: small single-block functions pay metadata setup cost even when unreachable/alias passes are skipped. Fix: compute complexity first, then build CFG only when needed (non-single-block unreachable cleanup or alias pass), and build domtree only when alias analysis runs. Verify: zig build test -j1 and same-tree A/B gate; keep only if >=5% retained gain and no regressions.
