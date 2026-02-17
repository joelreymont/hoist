---
title: Hoist try-call branch check
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T16:45:04.832157+01:00\\\"\""
closed-at: "2026-02-17T16:46:53.601767+01:00"
close-reason: discarded (<5% gains; gate showed no qualifying positive deltas)
---

Full context: src/codegen/compile.zig:1886-1917 lowerAArch64 checks every instruction via dfg.insts.get(inst) to detect try_call/try_call_indirect terminators. Cause: per-inst terminator detection does redundant hash lookups in lowering hot loop. Fix: track only block terminator inst during lowering loop and perform one post-loop check/branch emit. Proof: zig build test + bench-gate repeat=11; keep only if >=5% positive gains.
