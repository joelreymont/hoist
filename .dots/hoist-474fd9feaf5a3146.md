---
title: "optimizations: ISLE opts"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:02:25.599331+02:00\""
closed-at: "\"2026-01-01T17:05:05.320527+02:00\""
close-reason: "\"completed: src/dsl/isle/opts.isle with ISLE optimization rules (algebraic simplifications, constant folding, strength reduction, comparison/control flow opts). src/ir/optimize.zig with OptimizationPass applying pattern-based peephole optimizations. All tests pass.\""
blocks:
  - hoist-474fd6bb7295df44
---

src/opts/opts.isle -> opts_generated.zig

Compile optimization ISLE rules (~2.3k LOC ISLE):
- cranelift/codegen/src/opts/*.isle

Algebraic simplifications:
  (rule (iadd x 0) x)
  (rule (imul x 1) x)
  (rule (isub x x) (iconst 0))

Strength reduction:
  (rule (imul x (iconst_power_of_two n))
        (ishl x (iconst (log2 n))))

Constant folding:
  (rule (iadd (iconst a) (iconst b))
        (iconst (+ a b)))

Dead code:
- Unreachable block elimination
- Unused value removal

Applied during lowering via ISLE priority system
