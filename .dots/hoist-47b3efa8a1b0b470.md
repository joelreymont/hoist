---
title: Implement sload16 signed 16-bit load
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:26:45.788086+02:00"
closed-at: "2026-01-06T10:37:52.827130+02:00"
---

File: src/codegen/compile.zig - Add lowering for sload16. Use LDRSH (load signed halfword) which sign-extends. Critical P0.
