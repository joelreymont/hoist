---
title: Add tailcall move ordering (~80 lines)
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T11:25:31.738325+02:00"
closed-at: "2026-01-05T13:15:49.283627+02:00"
---

File: src/codegen/tailcall.zig. Optimize move ordering for tail calls to avoid clobbering. Build dependency graph, emit in correct order. Est: 20 min.
