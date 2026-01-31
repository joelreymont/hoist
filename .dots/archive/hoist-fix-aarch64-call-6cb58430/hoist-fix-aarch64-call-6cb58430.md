---
title: Fix AArch64 call ABI
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-30T18:12:28.663365+01:00\""
closed-at: "2026-01-31T14:59:56.601523+01:00"
close-reason: shared call layout + out stack space
---

Context: src/backends/aarch64/isle_helpers.zig:3930; cause: call arg marshalling duplicated and frame ignores stack args; fix: shared call layout + reserve outgoing stack space; deps: none; verification: new abi layout tests + zig build test
