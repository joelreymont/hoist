---
title: Reuse block map
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T23:37:41.300351+01:00\""
closed-at: "2026-02-17T23:41:31.014955+01:00"
close-reason: "discarded: gate regressions (fib/large100/serial)"
---

Full context: src/codegen/compile.zig lowerAArch64 allocates a fresh AutoHashMap block_index_map each compile (lines ~1640+), then fills by block iteration; this is a per-compile temporary that can retain capacity across runs. Cause: repeated map init/deinit alloc churn in lower hot path. Fix: persist/reuse temporary block_index_map in AArch64Lowered pipeline state with clearRetainingCapacity in resetForReuse and per-compile start. Verify: zig build test + parent-vs-current gate + rerun stability; keep only with >=5% retained gain and no regressions.
