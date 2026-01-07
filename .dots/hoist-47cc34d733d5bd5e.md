---
title: Platform-specific ABI compliance
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:05.683183+02:00"
---

NEW (oracle finding). X18 register: reserved on Darwin, available on Linux. Red zone: 128 bytes on Linux, none on Darwin. Minimum frame size: 16 bytes on Darwin. Test: Separate macOS and Linux test suites. Phase 1.4, Priority P0
