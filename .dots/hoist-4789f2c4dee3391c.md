---
title: "PHASE 1: Refactor explicit vector opcodes to type-parameterized rules"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:21:09.343987+02:00"
closed-at: "2026-01-04T08:30:24.734607+02:00"
---

File: src/backends/aarch64/lower.isle. Hoist has ~58 redundant explicit vector opcode rules (viadd, visub, vimul, vimax, vimin, vreduce_*) that should use Cranelift's type extractor pattern (multi_lane, ty_vec128). Replace explicit opcodes with type-parameterized rules. Also consolidate 5 fence rules to 1. Removes ~62 rules of bloat. 40-80h.
