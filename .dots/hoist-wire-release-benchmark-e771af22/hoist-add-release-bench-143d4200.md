---
title: Add release bench option
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T13:08:21.809197+01:00\\\"\""
closed-at: "2026-02-17T13:13:55.596871+01:00"
close-reason: added -Dbench-optimize with ReleaseFast default and wired benchmark, baseline, and perf_gate executables to bench-specific optimize mode in build.zig
---

Context: build.zig:52-72; cause: bench steps inherit global optimize and are easy to run in Debug unintentionally; fix: add explicit bench optimize option defaulting to ReleaseFast for bench/baseline/gate executables; deps: Wire release benchmark mode; verification: bench logs from bench-log show release-level timings and command-line override works.
