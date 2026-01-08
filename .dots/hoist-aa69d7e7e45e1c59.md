---
title: Emit BR for tail jump
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T12:45:35.391577+02:00"
---

File: src/backends/aarch64/isle_impl.zig,emit.zig - Instead of BL (link), emit BR (branch) for tail call. Or B (immediate) if direct call. No return expected. Depends on: frame deallocation. Enables: actual tail jump.
