---
title: Add probestack emission
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:56.757940+02:00\""
closed-at: "2026-01-26T09:44:00.795817+01:00"
---

In src/backends/aarch64, emit stack probes for large allocations. Call probestack libcall. Deps: Add probestack libcall sig. Verify: zig build test
