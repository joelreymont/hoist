---
title: Document AppleAarch64 differences
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T08:18:57.075815+02:00"
---

Research macOS ARM64 ABI differences from AAPCS64. Check: stack alignment (8 vs 16?), small struct handling, char signedness. Add to docs/calling-conventions.md section. Reference: clang -target arm64-apple-macos. ~90 min research.
