---
title: "Phase 1.2: Replace viadd with type-parameterized iadd"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:22:10.620093+02:00"
closed-at: "2026-01-04T08:30:24.739323+02:00"
---

File: src/backends/aarch64/lower.isle. Replace 7 viadd rules (lines 1361-1380) with single rule: (rule (lower (has_type (multi_lane _ _) (iadd x y))) (add_vec x y (vector_size ty))). Depends on Phase 1.1. 2-4h.
