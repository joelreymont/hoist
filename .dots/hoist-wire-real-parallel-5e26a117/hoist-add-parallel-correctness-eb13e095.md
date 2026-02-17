---
title: Add parallel correctness tests
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.942628+01:00"
---

Context: tests integration; cause: concurrent compile path lacks deep validation; fix: add deterministic integration tests for output equivalence vs serial compile; deps: Merge results deterministically; verification: tests pass under stress and repeated seeds.
