---
title: Saturating SIMD arithmetic
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:51.660752+02:00"
closed-at: "2026-01-07T16:00:52.493288+02:00"
---

NEW (oracle: missing sqadd/uqadd/sqsub/uqsub). Add SQADD/UQADD instructions to inst.zig. Add SQSUB/UQSUB instructions. Implement lowering rules in lower.isle. Test: i8x16.add_sat_s WebAssembly op. Phase 2.10, Priority P1
