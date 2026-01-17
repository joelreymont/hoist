---
title: Fix indir return
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.281412+02:00"
---

Files: tests/aarch64_indirect_return.zig, build.zig:244-256. Cause: ABI export change. Fix: update imports/usage and re-enable. Why: sret coverage. Verify: zig build test.
