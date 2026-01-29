---
title: Fix Optimizer Shift Strength Reduction
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.354314+01:00"
---

Context: src/ir/optimize.zig:265; cause: shift uses value twice; fix: use binary_imm64 or add shift-imm instruction and wire builder; deps: hoist-fix-optimizer-iconst-b266aeac; verification: optimize test for mul by power-of-two
