---
title: Skip domtree on no-opt
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T23:13:19.334042+01:00\\\"\""
closed-at: "2026-02-17T23:16:22.918809+01:00"
close-reason: "discarded: unstable; rerun failed gate (large(500)+6.45%)"
---

Context: optimize() computes dominator tree before early-return on !target.optimize; bench large metrics run with optimization disabled. Cause: wasted domtree build on no-opt path. Fix: keep CFG compute, move domtree compute after !target.optimize return so no-opt compiles skip it. Verify: zig build test -j1 and same-tree A/B gate; keep only if >=5% retained gains and no regressions.
