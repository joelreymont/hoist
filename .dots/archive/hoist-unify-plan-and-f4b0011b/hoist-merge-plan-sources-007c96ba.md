---
title: Merge plan sources
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-07T09:47:01.066654+01:00\""
closed-at: "2026-02-07T09:50:07.220487+01:00"
close-reason: completed
---

Context: /Users/joel/Work/hoist/PLAN.md, /Users/joel/Work/hoist/docs/arm64_parity_plan.md, /Users/joel/Work/hoist/docs/gap-closure-plan.md, /Users/joel/Work/hoist/docs/feature_gap_analysis.md, /Users/joel/Work/hoist/docs/cranelift_gap_analysis.md, /Users/joel/.claude/plans/fuzzy-sniffing-shamir.md contain overlapping tasks and priorities. Cause: parallel planning threads were never normalized into one canonical list. Fix: extract unified task taxonomy (correctness, ABI, exceptions, features, perf, object emission) and dedupe conflicting claims. Verification: canonical taxonomy captured in PLAN.md sections with source references.
