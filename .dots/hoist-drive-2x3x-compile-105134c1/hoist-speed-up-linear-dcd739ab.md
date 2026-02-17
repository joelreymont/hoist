---
title: Speed up linear scan allocator
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:07:40.557838+01:00"
---

Context: src/regalloc/linear_scan.zig:300-430; cause: hot path uses hash-map lookups and map indirection for each interval operation; fix: dense array-backed allocation tables and fewer dynamic lookups; deps: Speed up liveness analysis; verification: regalloc stage time reduced on large5000 benchmark and regalloc tests pass.
