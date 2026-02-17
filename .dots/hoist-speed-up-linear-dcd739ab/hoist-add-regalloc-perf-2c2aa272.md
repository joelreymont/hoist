---
title: Add regalloc perf benchmark test
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.868358+01:00"
---

Context: src/regalloc/linear_scan tests; cause: no stage-level perf guard for allocator changes; fix: add benchmark-oriented regression test with stable synthetic ranges; deps: Slim spill slot bookkeeping; verification: perf test baseline captured and compared in CI/local runs.
