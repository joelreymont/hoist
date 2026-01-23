---
title: Extend x64 isle
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.337010+02:00\""
closed-at: "2026-01-23T10:24:52.138290+02:00"
---

Files: src/backends/x64/lower.isle:1-88
Root cause: only minimal integer rules exist.
Fix: add integer ops, comparisons, calls, loads/stores, address-mode selection rules.
Why: MVP IR coverage on x64.
Deps: Add x64 alu, Add x64 mem, Add x64 branch.
Verify: add lower tests.
