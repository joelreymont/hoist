---
title: Hoist dead spill-use scan
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T16:36:53.036323+01:00\\\"\""
closed-at: "2026-02-17T16:39:32.766709+01:00"
close-reason: discarded (<5% perf gain vs gate baseline)
---

Full context: src/codegen/compile.zig:646-706 insertSpillScratch builds block_spill_uses and vreg_use_blocks with per-inst operand scans but never consumes either map (TODO only). Cause: dead analysis pass in hot compile path. Fix: remove unused first pass and associated allocations; keep second rewrite pass semantics unchanged. Proof: zig build test + baseline-log/bench-gate A/B with repeat=11, keep only if >=5% positive gain.
