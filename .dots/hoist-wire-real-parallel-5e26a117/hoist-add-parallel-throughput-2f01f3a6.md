---
title: Add parallel throughput benchmark
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.936415+01:00"
---

Context: bench tooling; cause: no measured speedup target for multicore compile; fix: add benchmark comparing single-thread vs parallel compile on function batches; deps: Merge results deterministically; verification: benchmark reports speedup and is tracked in perf JSON.
