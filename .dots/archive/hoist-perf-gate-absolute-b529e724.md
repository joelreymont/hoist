---
title: Perf gate absolute floor
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T14:53:33.627747+01:00\\\"\""
closed-at: "2026-02-17T14:54:32.069120+01:00"
close-reason: "Completed: percent+absolute regression gating wired through build and docs; test+bench-gate passed."
---

Full context: tools/perf_gate.zig currently fails on tiny absolute deltas when percent threshold barely crosses 5%; cause is percent-only regression criterion producing noise false positives; fix by adding min absolute regression threshold and wiring build option bench-min-regress-us; proof via zig build test and zig build bench-gate with repeat=5.
