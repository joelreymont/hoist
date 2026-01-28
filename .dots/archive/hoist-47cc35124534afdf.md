---
title: FP/SIMD arguments
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:09.554247+02:00"
closed-at: "2026-01-07T15:54:26.432420+02:00"
---

Marshal FP args to V0-V7. Handle mixed integer + FP arguments. Correct register class allocation. Respect AAPCS64 register usage. Test: Call with 4 int + 4 FP args. Phase 1.14, Priority P0
