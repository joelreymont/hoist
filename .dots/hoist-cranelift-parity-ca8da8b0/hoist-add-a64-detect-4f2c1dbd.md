---
title: Add a64 detect
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.723721+02:00\""
closed-at: "2026-01-23T20:52:46.579799+02:00"
---

Files: src/target/features.zig:83-88
Root cause: aarch64 feature detection is stubbed.
Fix: implement AT_HWCAP based detection on linux and sysctl on macos.
Why: enable LSE/NEON/SVE gating.
Deps: none.
Verify: feature detection tests.
