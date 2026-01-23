---
title: Add addr modes
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.793872+02:00\""
closed-at: "2026-01-23T23:57:50.589967+02:00"
---

Files: src/backends/aarch64/isle_helpers.zig:223-244, src/backends/x64/lower.isle:1-88
Root cause: address-mode selection is minimal.
Fix: add rules for scaled offsets, combined base+index modes, immediate folding.
Why: reduce instruction count.
Deps: Extend x64 isle, aarch64 lower rules.
Verify: lowering tests.
