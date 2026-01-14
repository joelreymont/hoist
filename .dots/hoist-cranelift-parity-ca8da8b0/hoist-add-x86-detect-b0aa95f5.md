---
title: Add x86 detect
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.717663+02:00"
---

Files: src/target/features.zig:83-88
Root cause: FeatureDetector.detect is placeholder.
Fix: implement x86_64 CPUID feature detection and map to Features.
Why: generate optimized code for host.
Deps: none.
Verify: feature detection tests.
