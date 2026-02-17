---
title: Add egraph gate regression tests
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.913070+01:00"
---

Context: src/codegen tests; cause: no tests assert skip/apply boundary behavior; fix: add tests for below-threshold skip and above-threshold apply with equivalent output; deps: Expose egraph threshold option; verification: tests pass and fail when threshold logic is broken.
