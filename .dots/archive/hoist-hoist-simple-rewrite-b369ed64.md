---
title: hoist-simple-rewrite-fastpath
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T09:12:13.058805+01:00\\\"\""
closed-at: "2026-02-18T09:17:17.719760+01:00"
close-reason: "completed: immediate repeat-9 A/B passed with >=5% wins on fib and large(100), zero gate regressions"
---

src/codegen/compile.zig rewriteRegisters aarch64 path uses generic recursive rewriteInstRegs for all instructions; add a specialized fast path for simple streams (mov_imm/add_rr/ret) used by large compile benchmarks, fallback to generic otherwise; gate with immediate repeat-9 A/B
