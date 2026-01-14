---
title: Fix const phis
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.787860+02:00"
---

Files: src/codegen/compile.zig:728-738
Root cause: removeConstantPhis is stubbed.
Fix: implement phi removal using block params and CFG predecessors.
Why: cleanup after SSA optimizations.
Deps: none.
Verify: IR optimization tests.
