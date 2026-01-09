---
title: Lower struct load/store to field accesses
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:45:41.917099+02:00\""
closed-at: "2026-01-09T08:20:48.116612+02:00"
---

Add ISLE rules to decompose struct operations into field-level loads/stores. Handle nested structs. Files: src/backends/aarch64/lower.isle:900+ (new rules). ~60 min.
