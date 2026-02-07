---
title: Unify plan and dot workflow
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-07T09:46:50.746387+01:00\""
closed-at: "2026-02-07T09:50:37.823980+01:00"
close-reason: completed
---

Context: /Users/joel/Work/hoist/PLAN.md and docs/*plan*.md contain overlapping/outdated parity plans with inconsistent dot linkage. Cause: plan sources diverged over time and task tracking drifted. Fix: merge plan sources into one canonical PLAN.md with dot-backed checklist semantics and explicit checkoff protocol. Verification: every canonical plan task has a dot id, and dot ls is empty after executing all plan-unification child dots.
