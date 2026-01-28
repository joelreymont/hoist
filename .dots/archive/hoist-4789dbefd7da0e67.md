---
title: Implement BIC fusion patterns
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:14:46.284366+02:00"
closed-at: "2026-01-04T08:20:33.171603+02:00"
---

File: src/backends/aarch64/lower.isle. Add ISLE rules to fuse band(x, bnot(y)) and band(bnot(x), y) into band_not opcode, which lowers to ARM64 BIC instruction. Covers scalar fits_in_64 types. This is PR-4 from parity plan - pilot implementation to validate effort estimates (2-4h target).
