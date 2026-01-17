---
title: Fix struct args
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.258709+02:00"
---

Files: tests/aarch64_struct_args.zig, build.zig:203-215. Cause: ABI export/API change. Fix: update imports + ABI types, re-enable. Why: struct ABI coverage. Verify: zig build test.
