---
title: Lazy domtree on no-opt
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T16:22:49.215691+01:00\""
closed-at: "2026-02-17T16:25:51.222621+01:00"
close-reason: "discarded: A/B improvements were <5% across single-thread metrics; reverted"
---

src/codegen/compile.zig: in optimize(), compute domtree only when target.optimize=true; for no-opt, compute it lazily in allocateRegisters only if spill insertion needs it. Validate A/B and keep only if >=5% positive.
