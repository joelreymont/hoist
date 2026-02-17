---
title: Add liveness perf regression test
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.845466+01:00"
---

Context: src/regalloc/liveness.zig tests; cause: no guardrail for liveness complexity regressions; fix: add deterministic large-CFG synthetic test with timing budget sanity check; deps: Optimize live-range reconstruction; verification: test passes and fails on intentional quadratic fallback.
