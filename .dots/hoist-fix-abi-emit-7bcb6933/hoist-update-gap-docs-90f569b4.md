---
title: Update gap docs
status: open
priority: 2
issue-type: task
created-at: "2026-01-14T13:03:09.894725+02:00"
---

Files: docs/COMPLETION_STATUS.md, docs/feature_gap_analysis.md. Root cause: docs claim AArch64 emit/ABI completeness while tests currently fail. Fix: update claims/gap list after closing encoding + ABI issues; note remaining real gaps only. Verify: re-read docs after tests pass.
