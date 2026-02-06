---
title: Fix TBZ/TBNZ label patching
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:25:11.362916+01:00\""
closed-at: "2026-02-06T22:27:46.768548+01:00"
close-reason: Use branch14 relocation to preserve bit-index fields
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/emit.zig:3526 and /Users/joel/Work/hoist/src/machinst/buffer.zig:599; cause: TBZ/TBNZ currently use branch19 fixup, which overwrites b40 bit-index field and applies wrong range; fix: add branch14 label use kind + patch path and switch TBZ/TBNZ to branch14; deps: none; verification: add branch14 fixup regression tests + zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
