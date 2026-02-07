---
title: Validate plan-dot canonical
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-07T09:51:44.152413+01:00\""
closed-at: "2026-02-07T09:51:53.670629+01:00"
close-reason: completed
---

Context: checkoff reliability requires direct ID resolvability. Cause: some legacy IDs in source docs are stale and archived child IDs are not directly resolvable by dot show. Fix: validate checklist formatting, validate referenced IDs, and retain stale IDs only in inventory report. Verification: dot ls empty and no unresolved IDs in PLAN.md checklist.
