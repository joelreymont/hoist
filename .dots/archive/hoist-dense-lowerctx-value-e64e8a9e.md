---
title: Dense LowerCtx value map
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:03:58.377708+01:00\\\"\""
closed-at: "2026-02-17T22:08:07.521965+01:00"
close-reason: "discarded: no >=5% retained gain"
---

Context: src/machinst/lower.zig value_to_reg is AutoHashMap and is queried on hot lowering paths (mapPinnedVReg, ISLE helpers, backend lowers). Cause: repeated hash lookups/puts for SSA value->vreg mapping. Fix: add dense value-indexed cache in LowerCtx with synchronized hash map boundary compatibility; migrate call sites to accessor methods. Why: reduce lowering-stage lookup overhead. Verify: zig build test + bench A/B with >=5% retained gains and no regressions.
