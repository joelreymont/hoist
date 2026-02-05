---
title: Wire regalloc bridge load/store
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-05T21:38:29.963909+01:00\\\"\""
closed-at: "2026-02-05T21:40:53.222614+01:00"
close-reason: Support load/store variants in regalloc bridge and add tests
---

Context: /Users/joel/Work/hoist/src/backends/aarch64/regalloc_bridge.zig:48 and /Users/joel/Work/hoist/src/backends/aarch64/inst.zig:2921; cause: bridge only supports arithmetic subset and rejects common load/store variants; fix: add extract/apply support for core load/store forms (ldr/str, byte/halfword/sign-ext, pair, pre/post, vector); deps: hoist-fix-regalloc-silent-9403f7f7; verification: new bridge tests + zig build test -j1 --global-cache-dir .zig-global-cache
