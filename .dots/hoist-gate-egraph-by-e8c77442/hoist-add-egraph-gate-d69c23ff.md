---
title: Add egraph gate regression tests
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T13:08:21.913070+01:00\\\"\""
closed-at: "2026-02-17T13:28:31.833613+01:00"
close-reason: "added regression tests in src/codegen/compile.zig for threshold gating: optimize pass activation test asserts egraph_rules_cache remains null when threshold is max and initializes when threshold is zero, plus shouldRunEGraph threshold tests"
---

Context: src/codegen tests; cause: no tests assert skip/apply boundary behavior; fix: add tests for below-threshold skip and above-threshold apply with equivalent output; deps: Expose egraph threshold option; verification: tests pass and fail when threshold logic is broken.
