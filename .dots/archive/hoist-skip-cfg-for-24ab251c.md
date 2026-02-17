---
title: Skip CFG for noopt single-block
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T15:54:49.811777+01:00\""
closed-at: "2026-02-17T15:56:45.563549+01:00"
close-reason: "discarded: A/B failed perf gate (fib +5.71%, serial batch +5.22% regression); reverted compile.zig changes"
---

src/codegen/compile.zig: for optimize=false and single-block IR, skip cfg/domtree computation in optimize(); in allocateRegisters run direct single-block liveness path without cfg/block-insns map. Measure A/B and keep only if >=5% positive.
