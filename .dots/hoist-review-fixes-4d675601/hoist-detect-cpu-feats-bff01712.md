---
title: Detect cpu feats
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-17T12:46:36.969723+02:00\""
closed-at: "2026-01-17T12:48:39.461389+02:00"
close-reason: split into arch-specific dots
---

Files: src/target/features.zig:83-120. Cause: detect() is placeholder. Fix: implement runtime detection for x86_64 (CPUID) and aarch64 (HWCAP/sysctl) with OS gates; return error.Unsupported if unavailable; merge with parsed features. Why: correct ISA feature gating. Verify: add tests for parse + detect on native (smoke).
