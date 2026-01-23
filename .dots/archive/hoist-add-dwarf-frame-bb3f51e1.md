---
title: Add DWARF frame info
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:53:56.747463+02:00\""
closed-at: "2026-01-26T09:05:35.660257+01:00"
---

In src/debug/dwarf.zig, generate .debug_frame/.eh_frame for unwinding. Deps: Add DWARF line info. Verify: zig build test
