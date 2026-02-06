---
title: Add TBZ/TBNZ emit fixup tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:28:48.589090+01:00\""
closed-at: "2026-02-06T22:31:01.969378+01:00"
close-reason: Cover branch14 patching in emitter end-to-end tests
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/emit.zig branch tests region; cause: need end-to-end emit+finalize regression to ensure TBZ/TBNZ use branch14 fixups and preserve bit-index fields; fix: add emitter tests asserting imm14 patch and b40 preservation for tbz/tbnz; deps: hoist-fix-tbz-tbnz-3cccc8d9; verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
