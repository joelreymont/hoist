---
title: Fix fp special
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-17T12:48:35.244508+02:00\""
closed-at: "2026-01-23T23:03:57.584954+02:00"
---

Files: tests/fp_special_values.zig, build.zig:164-175. Cause: unary_ieee32/64 API changes. Fix: update immediates + builder usage and re-enable. Why: FP correctness. Verify: zig build test.
