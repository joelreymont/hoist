---
title: Add SSE/AVX emission (~250 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:20:27.372728+02:00"
closed-at: "2026-01-05T13:15:31.753639+02:00"
---

File: src/backend/x64/emit_simd.zig. Emit movss, movsd, addps, mulpd, etc. Handle VEX/EVEX prefixes, vector sizes. Depends on: encoding helpers. Est: 50 min.
