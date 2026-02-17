---
title: Drop unused value-use pass
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-17T22:10:05.352376+01:00\\\"\""
closed-at: "2026-02-17T22:14:07.133058+01:00"
close-reason: "completed: retained >=5% wins on large(100)/large(500)/mixed; gate pass"
---

Context: src/machinst/lower.zig:245-297 computes value_uses with hash-map scans each compile, but no lowering/backend/generated code consumes value_uses. Cause: dead analysis in hot lower path. Fix: remove value_uses storage + computeValueUses pass and associated dead code/tests; keep correctness by running full tests. Verify: zig build test -j1 and baseline/current bench compare with >=5% retained gain, no regressions.
