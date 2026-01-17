---
title: Add runtime CPU detection
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:49.600299+02:00"
---

Create src/target/cpuid.zig. Detect ARM64 features at runtime: NEON, SVE, crypto. Deps: none. Verify: zig build test
