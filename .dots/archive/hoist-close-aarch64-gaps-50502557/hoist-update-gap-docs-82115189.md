---
title: Update gap docs
status: closed
priority: 3
issue-type: task
created-at: "\"2026-01-14T14:14:53.373358+02:00\""
closed-at: "2026-01-14T14:50:07.889464+02:00"
close-reason: doc update for atomic enc fixes
---

Files: docs/feature_gap_analysis.md, docs/COMPLETION_STATUS.md. Root cause: docs claim full AArch64 encoding coverage despite current gaps/fixes. Fix: update gap list, status counts, and note corrections after tests pass. Dependencies: hoist-wire-ldxr-stxr-4e6b67ab, hoist-fix-pre-post-61c6eebf, hoist-update-ldr-str-31332c9c, hoist-fix-adr-adrp-760a9b31, hoist-fix-simd-three-5bb4692a, hoist-fix-fp-unary-a9b41531, hoist-propagate-logic-imm-99f23f72. Why: keep docs accurate.
