---
title: Validate TBZ/TBNZ bit index range
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:31:30.189505+01:00\""
closed-at: "2026-02-06T22:34:47.873598+01:00"
close-reason: Reject out-of-range bit indices in bit-test branches
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/emit.zig:3510; cause: TBZ/TBNZ currently accept u8 bit indexes and silently truncate values >63; fix: reject out-of-range bit index and add regression tests; deps: hoist-fix-tbz-tbnz-3cccc8d9; verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
