---
title: Add x64 lower() entrypoint (~50 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:20:02.867735+02:00"
closed-at: "2026-01-05T13:15:31.736459+02:00"
---

File: src/backend/x64/lower.zig. Create main lower() function that dispatches to ISLE. Takes Inst and LowerCtx, returns generated instructions. Est: 15 min.
