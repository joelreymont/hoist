---
title: Add emission driver (~120 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:25:21.467316+02:00"
closed-at: "2026-01-05T13:15:49.276280+02:00"
---

File: src/codegen/emit_driver.zig. Drive emission: iterate MachInsts, call backend emit(), handle fixups. Depends on: label resolution, relocations. Est: 30 min.
