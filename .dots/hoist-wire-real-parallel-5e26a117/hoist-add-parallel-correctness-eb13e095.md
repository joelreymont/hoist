---
title: Add parallel correctness tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.942628+01:00\""
closed-at: "2026-02-17T13:46:56.613061+01:00"
close-reason: "added integration correctness coverage in src/context.zig for parallel API: mixed success/failure mapping by function index and serial-vs-parallel byte equivalence assertions; deterministic sorted outputs validated through compileFunctionsParallel tests; full zig build test passes"
---

Context: tests integration; cause: concurrent compile path lacks deep validation; fix: add deterministic integration tests for output equivalence vs serial compile; deps: Merge results deterministically; verification: tests pass under stress and repeated seeds.
