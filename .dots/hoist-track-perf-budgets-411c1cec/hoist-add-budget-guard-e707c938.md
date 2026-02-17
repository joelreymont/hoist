---
title: Add budget guard thresholds
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.955969+01:00"
---

Context: tools/perf_gate.zig; cause: gate checks only per-run regression and not long-term progress targets; fix: add budget checks for key metrics toward 2x/3x targets with explicit failure messages; deps: Persist perf history json; verification: synthetic budget breach triggers non-zero exit.
