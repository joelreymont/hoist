---
title: Hoist bound peephole fixpoint
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T16:41:15.397004+01:00\\\"\""
closed-at: "2026-02-17T16:43:33.519927+01:00"
close-reason: "discarded (perf gate fail: large100 +9.84% regression; no >=5% gains)"
---

Full context: src/codegen/compile.zig:2160-2200 emitAArch64WithAllocation runs up to 3 full peephole iterations per block regardless of block size; large blocks dominate emit stage (~311us at large5000). Cause: unconditional multi-pass peephole fixpoint in hot path. Fix: bound iteration count by block instruction span (1 pass for large blocks, 3 for small blocks) to reduce compile-time scans while preserving correctness. Proof: zig build test + bench-gate repeat=11; keep only if >=5% positive metrics.
