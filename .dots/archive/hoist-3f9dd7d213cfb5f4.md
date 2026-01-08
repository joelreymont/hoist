---
title: Define CIE structure
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T21:19:44.230013+02:00"
---

File: src/backends/aarch64/unwind.zig (new). Define CommonInformationEntry struct: version (1), augmentation ('zR'), code_align (4), data_align (-8 for aarch64), return_reg (LR=30). Add encode() method. ~15 min.
