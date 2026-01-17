---
title: Wire debug info to emission
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:56.752745+02:00"
---

In src/backends/aarch64/emit.zig, emit debug info alongside instructions. Deps: Add DWARF frame info. Verify: zig build test
