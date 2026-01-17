---
title: Detect x86 cpuid
status: open
priority: 1
issue-type: task
created-at: "2026-01-17T12:48:35.348888+02:00"
---

Files: src/target/features.zig:83-120. Cause: detect() is placeholder. Fix: implement x86_64 CPUID detection (SSE/AVX/etc) with OS gating, update Features bits. Why: runtime feature gating. Verify: add smoke test on x86_64 builds.
