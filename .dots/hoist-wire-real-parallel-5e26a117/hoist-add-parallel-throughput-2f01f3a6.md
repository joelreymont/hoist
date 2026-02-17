---
title: Add parallel throughput benchmark
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.936415+01:00\""
closed-at: "2026-02-17T13:54:23.283497+01:00"
close-reason: added bench/compile_parallel.zig serial-vs-parallel batch compile benchmark, wired build.zig bench/baseline/bench-log/bench-gate to include bench_parallel, and extended tools/perf_gate.zig parsing/reporting with serial/parallel batch compile metrics now tracked in markdown/json reports
---

Context: bench tooling; cause: no measured speedup target for multicore compile; fix: add benchmark comparing single-thread vs parallel compile on function batches; deps: Merge results deterministically; verification: benchmark reports speedup and is tracked in perf JSON.
