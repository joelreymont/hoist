---
title: "P3.3: Add extended operand optimization patterns"
status: closed
priority: 3
issue-type: task
created-at: "2026-01-04T12:55:44.649406+02:00"
closed-at: "2026-01-04T13:03:18.459989+02:00"
---

HIGH PRIORITY - Extra instructions on every add with extension. Add 3 extended_value_from_value patterns for iadd/isub. Common in address calculations with sign-extended indices. Cranelift ref: lower.isle lines 76, 79, 754. Files: src/backends/aarch64/lower.isle. Est: 0.5 day.
