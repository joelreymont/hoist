---
title: Add function complexity score
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T13:08:21.896008+01:00\\\"\""
closed-at: "2026-02-17T13:17:52.099178+01:00"
close-reason: added deterministic estimateFunctionComplexity scoring in optimize pipeline, persisted score in codegen context, and added tests for determinism and monotonic growth with larger IR
---

Context: src/codegen/compile.zig:995-1018; cause: optimizer lacks cheap heuristic to skip expensive global rewrites; fix: compute function complexity from block/inst/value counts before egraph pass; deps: Gate egraph by complexity; verification: score is deterministic and covered by tests.
