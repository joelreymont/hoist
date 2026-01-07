---
title: "P3.2: Add immediate folding optimizations"
status: closed
priority: 3
issue-type: task
created-at: "2026-01-04T12:55:44.274164+02:00"
closed-at: "2026-01-04T13:03:18.080423+02:00"
---

HIGH PRIORITY - 5-10% instruction overhead without this. Add 4 imm12_from_value patterns for iadd/isub with small constants. Common in address calculations, array indexing. Cranelift ref: lower.isle lines 68-74. Files: src/backends/aarch64/lower.isle. Est: 0.5-1 day.
