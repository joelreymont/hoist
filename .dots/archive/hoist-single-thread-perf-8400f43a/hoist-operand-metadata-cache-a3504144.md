---
title: Operand metadata cache
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T20:38:18.759373+01:00\\\"\""
closed-at: "2026-02-17T21:54:10.010179+01:00"
close-reason: "discarded: no >=5% retained gain (best ~3.63%)"
blocks:
  - hoist-dense-regalloc-state-f8cf4fb4
---

Context: src/backends/aarch64/inst.zig:getOperands/getDefs/getUses, src/regalloc/liveness.zig:233-297,322-626, src/codegen/compile.zig:1964-2000. Cause: def/use extraction is recomputed across liveness+coalescing+regalloc traversals. Fix: cache compact def/use metadata once per lowered instruction and reuse everywhere that needs operand classes/uses/defs. Why: remove repeated operand-collection overhead in hot pipeline stages. Verify: zig build test && bench-gate A/B; retain only >=5% gains.
