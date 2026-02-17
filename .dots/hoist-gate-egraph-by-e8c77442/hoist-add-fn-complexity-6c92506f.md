---
title: Add function complexity score
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.896008+01:00"
---

Context: src/codegen/compile.zig:995-1018; cause: optimizer lacks cheap heuristic to skip expensive global rewrites; fix: compute function complexity from block/inst/value counts before egraph pass; deps: Gate egraph by complexity; verification: score is deterministic and covered by tests.
