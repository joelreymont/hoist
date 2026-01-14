---
title: Fix a64 callconv
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.518477+02:00"
---

Files: src/context.zig:99-107
Root cause: aarch64 default call conv hardcoded to apple_aarch64.
Fix: select system_v for linux and apple_aarch64 for macos, add windows if needed.
Why: correct ABI per OS.
Deps: none.
Verify: context tests in src/context.zig.
