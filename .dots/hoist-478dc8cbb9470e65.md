---
title: "P3.4: Implement I128 bit manipulation ops"
status: closed
priority: 3
issue-type: task
created-at: "2026-01-04T12:55:45.019217+02:00"
closed-at: "2026-01-04T13:11:17.687510+02:00"
---

HIGH PRIORITY - Correctness issue for 128-bit integers. Add 6 ops: bitrev, bswap, clz, ctz, cls, popcnt for I128. Multi-register operations, complex. Affects crypto, UUID, 128-bit math. Cranelift ref: lower.isle lines 1953, 2055, 1971, 2001, 2027, 2109. Files: src/backends/aarch64/lower.isle, isle_helpers.zig. Est: 2-3 days.
