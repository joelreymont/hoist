---
title: Add liveness perf regression test
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.845466+01:00\""
closed-at: "2026-02-17T14:14:46.583163+01:00"
close-reason: added deterministic wide-CFG liveness perf sanity test in src/regalloc/liveness.zig using computeLivenessWithCFGInto with runtime budget guard; validated with zig build test
---

Context: src/regalloc/liveness.zig tests; cause: no guardrail for liveness complexity regressions; fix: add deterministic large-CFG synthetic test with timing budget sanity check; deps: Optimize live-range reconstruction; verification: test passes and fails on intentional quadratic fallback.
