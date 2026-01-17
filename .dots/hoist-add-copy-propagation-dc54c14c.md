---
title: Add copy propagation pass
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:05:07.646437+02:00"
---

Files: src/codegen/optimize.zig (new section)
What: Implement copy propagation to eliminate redundant moves
Algorithm: Track def-use chains, replace uses of copy with original
Run after regalloc to clean up unnecessary register moves
Verification: Check instruction count reduction
