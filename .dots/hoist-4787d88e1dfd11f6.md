---
title: Implement uimm16 extractor
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T05:50:39.613447+02:00"
closed-at: "2026-01-04T05:53:01.681021+02:00"
---

File: src/backends/aarch64/isle_helpers.zig - Add extractor function that validates a u64 fits in 16-bit unsigned (0-65535) and returns it if valid, null otherwise. Used in ISLE rules for immediate operands requiring 16-bit range. Pattern: pub fn uimm16(val: u64) ?u64 { if (val <= 65535) return val; return null; }
