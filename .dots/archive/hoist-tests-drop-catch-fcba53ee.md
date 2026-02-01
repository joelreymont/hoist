---
title: "Tests: drop catch unreachable"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-01T14:17:38.572952+01:00\""
closed-at: "2026-02-01T14:18:20.257430+01:00"
close-reason: completed
---

tests/e2e_calls.zig:41 etc, tests/compile_loops.zig:24 etc cause: error masking on makeBlock allocation; fix: use try makeBlock in tests; why: propagate alloc errors per rules.
