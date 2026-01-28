---
title: Add probestack integration (~60 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:20:43.280116+02:00"
closed-at: "2026-01-05T13:15:49.112895+02:00"
---

File: src/backend/x64/abi_probestack.zig. Call __chkstk or __rust_probestack for large stack frames. Emit probing sequence. Est: 15 min.
