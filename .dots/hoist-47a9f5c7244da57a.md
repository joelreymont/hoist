---
title: Verify offset range legalization for address modes
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:38.777943+02:00"
closed-at: "2026-01-06T19:39:27.783724+02:00"
---

File: src/codegen/lower_aarch64.zig. Ensure large offsets (>4KB) handled: materialize offset in register, use [base, reg] addressing. Negative offsets: SUB or use register mode. Unaligned: adjust base. VERIFY: Is this already in address mode selection dots? If not, implement. Dependencies: immediate materialization. Effort: 1 day (if separate).
