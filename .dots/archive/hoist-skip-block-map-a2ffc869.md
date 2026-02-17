---
title: Skip block map on single CFG block
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T15:44:55.002008+01:00\""
closed-at: "2026-02-17T15:46:13.249506+01:00"
close-reason: "discarded: no >=5% positive gain under A/B gate; reverted compile.zig change"
---

src/codegen/compile.zig allocateRegisters currently allocates/populates block_insns for all functions before liveness. For single-block CFG, compute vcode block from entry block directly and avoid block_insns alloc+populate. Measure A/B; keep only if >=5% positive.
