---
title: Add x64 shadow
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.594785+02:00"
---

Files: src/backends/x64/abi.zig:19-57
Root cause: Windows x64 shadow space not modeled.
Fix: reserve 32-byte shadow space and home registers per Win64 ABI.
Why: Windows ABI parity.
Deps: Fix x64 stack.
Verify: ABI tests for windows_fastcall.
