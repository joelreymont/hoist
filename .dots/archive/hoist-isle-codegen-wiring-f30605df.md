---
title: ISLE codegen wiring
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T20:16:20.209828+01:00\""
closed-at: "2026-02-02T08:33:06.910247+01:00"
close-reason: completed
---

Full context: src/dsl/isle/compile.zig:47 uses stub codegen.zig, no extractor/constructor emission. Cause: compile path not wired to match/constructors/extractors. Fix: route through match compiler + emit constructors/extractors; emit extern stubs. Why: generate real lowering.
