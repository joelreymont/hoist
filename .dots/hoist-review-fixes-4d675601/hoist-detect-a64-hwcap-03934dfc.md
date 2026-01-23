---
title: Detect a64 hwcap
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-17T12:48:35.356686+02:00\""
closed-at: "2026-01-23T23:17:30.127584+02:00"
---

Files: src/target/features.zig:83-120. Cause: detect() is placeholder. Fix: implement aarch64 HWCAP (Linux) + sysctl (macOS) detection, map to feature bits. Why: runtime feature gating. Verify: add smoke test on aarch64 builds.
