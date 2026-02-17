---
title: Compact vreg origin
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-18T00:13:17.277941+01:00\\\"\""
closed-at: "2026-02-18T00:22:26.590248+01:00"
close-reason: "discarded: improvements <5% threshold"
---

Full context: after removing non-const origin writes, VRegOrigin still stores unused binop operands and helper APIs. Cause: larger map value payload and dead API surface. Fix: shrink VRegOrigin to {opcode, imm}; remove forBinop/isCheap and dead fields. Verify with tests and fresh repeat-9 baseline gate; keep only if >=5% retained gains and no regressions.
