---
title: Add array-backed alloc result
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.851126+01:00"
---

Context: src/regalloc/linear_scan.zig:45-90; cause: vreg_to_preg and vreg_to_spill hash lookups are hot; fix: introduce dense array-backed storage keyed by compact vreg index with fallback conversion only at boundaries; deps: Speed up liveness analysis; verification: regalloc unit tests pass with identical allocation behavior.
