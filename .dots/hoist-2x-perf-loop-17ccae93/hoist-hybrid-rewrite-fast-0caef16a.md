---
title: hybrid rewrite fast path per instruction
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T21:39:58.861272+01:00\\\"\""
closed-at: "2026-02-21T21:45:15.269715+01:00"
close-reason: "discarded: repeat-9 compare reported regressions on large compile metrics"
---

Context: src/codegen/compile.zig rewriteAArch64SimpleFast bails to full reflective rewrite if any unsupported opcode exists, causing all instructions to pay slow path. Hypothesis: convert to hybrid per-instruction fast rewrite (manual cases for common opcodes, fallback only per unsupported instruction) to cut rewrite-stage cost on large no-opt functions. Verify: zig build test -j1; repeat-9 gate vs /tmp/hoist-2x-loop-base-r9.log; keep only with >=5% positive wins and no regressions.
