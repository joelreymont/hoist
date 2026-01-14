---
title: Add ssa builder
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.700627+02:00"
---

Files: src/ir/ssa_tests.zig:1-120
Root cause: no block sealing/phi insertion builder.
Fix: implement SSA builder with use_var/def_var and block sealing.
Why: simplify frontend IR construction.
Deps: Add ssa vars.
Verify: SSA builder tests.
