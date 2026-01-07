---
title: "Fix encodeFloatImmediate for standard FP values in src/backends/aarch64/encoding.zig:249 - algorithm fails for 2.0 and -0.5, needs correct exponent pattern check (must be 10xxxxxx range 0x200-0x3FF, not 0x380-0x47F)"
status: closed
priority: 1
issue-type: task
created-at: "2026-01-02T19:37:44.351233+02:00"
closed-at: "2026-01-02T19:41:55.287212+02:00"
close-reason: completed - commit dbcf886
---
