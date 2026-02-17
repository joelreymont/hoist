---
title: Drop lower uses
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T23:23:54.986005+01:00\""
closed-at: "2026-02-17T23:29:42.702697+01:00"
close-reason: "discarded: no >=5% retained wins; mixed micro regressions"
---

Full context: src/machinst/lower.zig:93-132,247-494 keeps value_uses map + computeValueUses pass that is not consumed by production lowering; remove from hot path and tests, preserve semantics; proof via zig build test + perf gate compare against parent baseline; keep only if >=5% retained gain and zero regressions.
