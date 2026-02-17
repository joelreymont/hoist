---
title: Add regalloc perf benchmark test
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.868358+01:00\""
closed-at: "2026-02-17T14:13:36.569467+01:00"
close-reason: added synthetic regalloc perf sanity test in src/regalloc/linear_scan.zig with deterministic 4000-range workload and runtime budget guard; validated with zig build test
---

Context: src/regalloc/linear_scan tests; cause: no stage-level perf guard for allocator changes; fix: add benchmark-oriented regression test with stable synthetic ranges; deps: Slim spill slot bookkeeping; verification: perf test baseline captured and compared in CI/local runs.
