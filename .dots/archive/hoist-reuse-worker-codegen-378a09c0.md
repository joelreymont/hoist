---
title: Reuse worker codegen ctx
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T15:41:48.184583+01:00\""
closed-at: "2026-02-17T15:44:32.300189+01:00"
close-reason: "canceled: out of scope per directive; focus is single-thread performance only"
---

src/codegen/parallel.zig workerLoop/compileFunction currently allocates Arena+codegen Context per function. Move to one reusable Context per worker thread, clear between jobs, preserve correctness, and measure A/B. Keep only if >=5% positive on parallel batch or other tracked metrics.
