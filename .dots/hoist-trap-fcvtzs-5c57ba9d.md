---
title: Trap fcvtzs
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T18:27:04.084145+01:00"
---

Context: src/backends/aarch64/isle_helpers.zig:2195-2211; cause: trapping conversion uses saturating fallback; fix: emit NaN/overflow/underflow checks and trap blocks; deps: none; verification: zig build test
