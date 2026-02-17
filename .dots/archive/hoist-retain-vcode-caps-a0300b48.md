---
title: Retain vcode caps
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T23:55:28.101020+01:00\""
closed-at: "2026-02-17T23:58:52.000789+01:00"
close-reason: "discarded: gate regressions on large benchmarks"
---

Full context: AArch64Lowered.resetForReuse in src/codegen/pipeline_state.zig deinit+reinits VCode, dropping all array capacity every compile. Cause: reuse path still churns allocator for insns/blocks/succs/preds/params/phi groups. Fix: add VCode.resetForReuse() to clearRetainingCapacity on all backing arrays and switch AArch64Lowered.resetForReuse to call it. Verify with tests and parent-vs-current gate + rerun; keep only with >=5% retained gains and no regressions.
