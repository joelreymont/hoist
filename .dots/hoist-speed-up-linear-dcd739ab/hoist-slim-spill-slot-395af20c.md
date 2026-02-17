---
title: Slim spill slot bookkeeping
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.862785+01:00"
---

Context: src/regalloc/linear_scan.zig:357-385; cause: active-list compaction and spill-slot map checks add overhead; fix: use compact free lists and direct state flags per interval; deps: Use dense lookup in hot loops; verification: no functional change in spill behavior tests and lower regalloc time.
