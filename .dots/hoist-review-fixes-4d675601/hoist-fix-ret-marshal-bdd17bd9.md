---
title: Fix ret marshal
status: closed
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.273878+02:00"
closed-at: "2026-01-23T21:11:08.000000+00:00"
---

Files: tests/aarch64_return_marshaling.zig, build.zig:231-242. Cause: Imm64 API change and sig builder changes. Fix: update to Imm64.new and Signature APIs; re-enable. Why: return ABI coverage. Verify: zig build test.
