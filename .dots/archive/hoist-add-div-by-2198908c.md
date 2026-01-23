---
title: Add div-by-constant opt
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T15:05:08.959473+02:00\""
closed-at: "2026-01-24T00:30:27.716639+02:00"
---

Files: src/codegen/optimize.zig or src/backends/aarch64/isle_impl.zig
What: Replace integer division by constant with multiply-shift sequence
Algorithm: Use magic number multiplication (Hacker's Delight)
Already have div_const.zig - wire it into lowering
Verification: Test div by powers of 2 and other constants
