---
title: Use dense lookup in hot loops
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.857318+01:00"
---

Context: src/regalloc/linear_scan.zig:300-430; cause: allocate/expire/spill repeatedly query maps; fix: refactor hot loops to direct array lookup and update paths; deps: Add array-backed alloc result; verification: large5000 regalloc stage time decreases and tests pass.
