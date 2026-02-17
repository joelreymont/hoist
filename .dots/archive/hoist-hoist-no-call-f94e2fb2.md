---
title: Hoist no-call regalloc fastpath
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T16:47:35.681155+01:00\\\"\""
closed-at: "2026-02-17T16:49:58.253137+01:00"
close-reason: discarded (no stable >=5% gains across repeated bench-gate runs)
---

Full context: src/regalloc/linear_scan.zig allocateInto calls spansCall() for every live range; most benchmark functions have no calls, so this repeated check is pure overhead in hot loop. Cause: unconditional per-range call-span query. Fix: precompute has_calls once per allocation and bypass spansCall when call_positions is empty. Proof: zig build test + bench-gate repeat=11; keep only if >=5% positive metrics.
