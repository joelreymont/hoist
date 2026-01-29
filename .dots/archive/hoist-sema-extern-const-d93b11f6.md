---
title: Sema extern+const
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-29T20:16:08.357561+01:00\""
closed-at: "2026-01-29T20:40:08.766994+01:00"
close-reason: completed
---

Full context: src/dsl/isle/sema.zig:489/572/669 missing extern mapping and const_prim resolution (/). Cause: no extern info or const typing. Fix: track extern func names/kinds; resolve consts via expected type and enum variants. Why: type-check real ISLE.
