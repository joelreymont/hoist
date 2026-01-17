---
title: Fix e2e branches
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:47:07.053873+02:00"
---

Files: tests/e2e_branches.zig, build.zig:100-112. Cause: API drift (createInst->makeInst, return format, ContextBuilder defaults). Fix: update to current InstructionData/Function APIs and re-enable test in build.zig. Why: restore branch E2E coverage. Verify: zig build test (test step includes e2e_branches).
