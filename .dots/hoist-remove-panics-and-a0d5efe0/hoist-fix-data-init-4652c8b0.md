---
title: Fix Data.Init.size Panic
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.531130+01:00"
---

Context: src/module/data.zig:10; cause: uninit size panics; fix: return error and update callers; deps: hoist-remove-panics-and-a0d5efe0; verification: unit tests updated
