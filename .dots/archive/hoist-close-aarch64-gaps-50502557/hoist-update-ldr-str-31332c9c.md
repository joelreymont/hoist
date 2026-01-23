---
title: Update ldr/str reg tests
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-14T14:14:24.073295+02:00\\\"\""
closed-at: "2026-01-14T14:20:20.117387+02:00"
close-reason: updated ldr/str reg+shifted expectations to spec
---

Files: src/backends/aarch64/emit.zig:8420-9165. Root cause: test expectations assume sf bit and old encodings after size-bit fix; str_shifted format asserts bit31=0 for 32-bit. Fix: update expected constants for ldr/str reg/ext/shifted + no-shift cases and adjust bit31 assertion to reflect size bits (31-30). Why: keep tests aligned with ARM encodings and recent size-bit correction.
