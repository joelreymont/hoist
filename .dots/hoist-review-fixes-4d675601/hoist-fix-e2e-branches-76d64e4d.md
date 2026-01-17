---
title: Fix e2e branches
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.221819+02:00"
---

Files: tests/e2e_branches.zig, build.zig:100-112. Cause: API drift (makeInst, Imm64.new, branch data fields). Fix: update test to current APIs and re-enable in build.zig. Why: branch E2E coverage. Verify: zig build test (includes e2e_branches).
