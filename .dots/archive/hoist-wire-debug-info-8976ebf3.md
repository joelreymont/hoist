---
title: Wire debug info to emission
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:56.752745+02:00\""
closed-at: "2026-01-26T10:00:43.196571+01:00"
---

In src/backends/aarch64/emit.zig, emit debug info alongside instructions. Deps: Add DWARF frame info. Verify: zig build test
