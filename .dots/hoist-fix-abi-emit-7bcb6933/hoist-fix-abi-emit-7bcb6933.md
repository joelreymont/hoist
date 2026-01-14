---
title: Fix ABI/emit gaps
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T13:01:22.458224+02:00"
---

Context: src/backends/aarch64/emit.zig, src/backends/aarch64/inst.zig, src/machinst/abi.zig, docs/COMPLETION_STATUS.md, docs/feature_gap_analysis.md. Root cause: AArch64 emit missing/incorrect encodings and ABI slot allocation bugs cause test failures; docs overstate completeness. Fix: correct encodings + add missing inst variants, repair ABI arg/ret slots, update docs, rerun tests.
