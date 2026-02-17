---
title: Bench gate + report
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T11:42:08.548124+01:00"
---

Add repeatable perf gate and report script for bench/fib/large/aarch64 outputs. files: bench/*.zig, scripts (if needed), docs/COMPLETION_STATUS.md. Cause: no enforced perf regression guard. Fix: produce before/after table and threshold checks. Why: lock in 2-3x gains.
