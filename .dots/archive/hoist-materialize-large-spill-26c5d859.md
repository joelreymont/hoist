---
title: Materialize large spill offsets
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-07T01:10:05.780336+01:00\""
closed-at: "2026-02-07T09:34:17.989034+01:00"
close-reason: completed
---

Context: src/backends/aarch64/regalloc_bridge.zig:804-906 uses ldr/str imm9 for int spill reloads. Cause: offsets >255 produce unencodable loads/stores after regalloc. Fix: materialize SP+slot in scratch int register for large int spill slots, then load/store at offset 0; keep direct path for small offsets. Add/adjust regalloc bridge tests for large slot behavior and run zig build test -j1 --global-cache-dir .zig-global-cache.
