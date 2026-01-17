---
title: Add probestack emission
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:56.757940+02:00"
---

In src/backends/aarch64, emit stack probes for large allocations. Call probestack libcall. Deps: Add probestack libcall sig. Verify: zig build test
