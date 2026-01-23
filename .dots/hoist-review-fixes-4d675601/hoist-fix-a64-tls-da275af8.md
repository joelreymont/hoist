---
title: Fix a64 tls
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-17T12:48:35.237375+02:00\\\"\""
closed-at: "2026-01-23T07:13:51.569382+02:00"
---

Files: tests/aarch64_tls.zig, build.zig:151-162. Cause: compileFunction API change. Fix: update context usage and re-enable. Why: TLS regression coverage. Verify: zig build test.
