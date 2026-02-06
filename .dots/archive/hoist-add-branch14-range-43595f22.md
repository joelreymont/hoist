---
title: Add branch14 range regression test
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:34:59.309339+01:00\""
closed-at: "2026-02-06T22:37:02.920274+01:00"
close-reason: Add branch14 range regression to prevent offset overflow
---

Context: /Users/joel/Work/hoist/src/machinst/buffer.zig branch14 finalize path; cause: branch14 fixup needs explicit out-of-range coverage to prevent silent overflow; fix: add test that places target at +8192 words and expects BranchOutOfRange; deps: hoist-fix-tbz-tbnz-3cccc8d9; verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
