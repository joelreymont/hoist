---
title: Add DWARF frame info
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T14:53:56.747463+02:00"
---

In src/debug/dwarf.zig, generate .debug_frame/.eh_frame for unwinding. Deps: Add DWARF line info. Verify: zig build test
