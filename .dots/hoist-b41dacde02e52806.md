---
title: Implement HFA/HVA classification
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T07:48:06.553433+02:00"
---

Add isHomogeneousAggregate() helper to detect HFA (1-4 float/double) and HVA (1-4 same-size vectors). Classify these in s0-s7/d0-d7/v0-v3 per AAPCS64 B.4-B.5. Files: src/backends/aarch64/abi.zig:350+ (new section), ~120 lines. ~90 min.
