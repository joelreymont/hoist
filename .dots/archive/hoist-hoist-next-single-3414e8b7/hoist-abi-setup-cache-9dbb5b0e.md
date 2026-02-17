---
title: ABI setup cache
status: closed
priority: 3
issue-type: task
created-at: "\"2026-02-17T18:21:36.889193+01:00\""
closed-at: "2026-02-17T18:39:02.889912+01:00"
close-reason: discarded (<5% retained gain)
---

Full context: emitAArch64WithAllocation rebuilds ABI signature vectors each compile. Cause: repeated setup churn in batch workloads. Fix: cache per-signature ABI setup in codegen context and reuse when unchanged.
