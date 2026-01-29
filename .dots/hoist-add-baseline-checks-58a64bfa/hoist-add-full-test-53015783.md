---
title: Add Full Test Baseline
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-29T10:05:45.310246+01:00\\\"\""
closed-at: "2026-01-29T10:08:15.907704+01:00"
close-reason: "blocked: zig build test hangs after e2e_jit output; needs test isolation"
---

Context: build.zig:1; cause: unknown failing tests; fix: run zig build test with NO_COLOR and save /tmp/hoist-test.log; deps: hoist-add-baseline-checks-58a64bfa; verification: log saved + failing list recorded
