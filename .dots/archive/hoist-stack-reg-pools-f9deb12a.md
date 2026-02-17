---
title: Stack reg pools
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T15:39:18.894180+01:00\""
closed-at: "2026-02-17T15:41:18.147469+01:00"
close-reason: "discarded: A/B regression >5% on multiple metrics (see /tmp/hoist-pools-ab.md); reverted compile.zig changes"
---

src/codegen/compile.zig allocateRegisters/buildAarch64Pools: remove per-compile heap allocations for AArch64 allocable register pools by using fixed-size stack buffers and slices. Measure A/B with bench-log+perf_gate; keep only if >=5% positive on tracked metrics.
