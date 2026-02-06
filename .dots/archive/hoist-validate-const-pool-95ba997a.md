---
title: Validate constant pool entry size
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:08:41.592170+01:00\""
closed-at: "2026-02-06T23:10:47.149043+01:00"
close-reason: Reject invalid constant sizes before pool emission
---

Context: /Users/joel/Work/hoist/src/machinst/buffer.zig:addConstant; cause: addConstant accepts arbitrary size and defers failure to emitConstPool; fix: reject non-{4,8} sizes in addConstant and cover with regression test; deps: hoist-fix-const-pool-cac47e86; verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
