---
title: Wire strict gate
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T12:20:58.195011+01:00\""
closed-at: "2026-02-17T12:27:52.308972+01:00"
close-reason: wired build bench-repeat option, bench-report-json-path output, and bench-gate dependencies on fresh baseline-log+bench-log captures
---

file: build.zig. cause: bench-gate did not enforce fresh baseline/current paired captures. fix: add repeat options, baseline dependency, and report output options. why: prevent stale-baseline false passes.
