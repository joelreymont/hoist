---
title: Trap fcvtzs
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.736206+01:00"
blocks:
  - hoist-lower-x64-branches-d5491c37
---

Context: src/backends/aarch64/isle_helpers.zig:2195-2211; cause: trapping conversion uses saturating fallback; fix: emit NaN/overflow/underflow checks and trap blocks; deps: none; verification: zig build test
