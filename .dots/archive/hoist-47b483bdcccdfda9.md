---
title: Add rematerialization tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:08:10.203352+02:00"
closed-at: "2026-01-07T06:30:44.185342+02:00"
---

File: tests/rematerialization.zig - Test: iconst under pressure (rematerialized instead of spilled), ADD with available inputs (rematerialized), complex expr (spilled not rematerialized). Measure: fewer stack slots used, fewer LDR instructions. Compare to pure spilling. Dependencies: hoist-47b4835bdda4036e.
