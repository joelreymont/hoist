---
title: Implement load/store pair optimization (LDP/STP)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:38.400836+02:00"
closed-at: "2026-01-06T20:18:33.241453+02:00"
---

File: src/codegen/lower_aarch64.zig. Pattern matching: detect two adjacent loads/stores with offsets differing by 8 (64-bit) or 4 (32-bit). Generate LDP/STP (2x memory bandwidth). Constraints: 8-byte aligned, 7-bit signed scaled immediate offset (-512 to +504 for 64-bit). Profitability: usually beneficial, but consider cache line boundaries. Dependencies: address mode selection. Effort: 2-3 days.
