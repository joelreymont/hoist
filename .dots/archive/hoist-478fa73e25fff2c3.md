---
title: Fix ArrayList.len API change
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T15:09:32.027400+02:00"
closed-at: "2026-01-04T15:10:50.537027+02:00"
---

Zig 0.15 changed ArrayList.len field to items.len. Affects tests/e2e_*.zig files. Need to change code.len to code.items.len for ArrayList(u8) instances.
