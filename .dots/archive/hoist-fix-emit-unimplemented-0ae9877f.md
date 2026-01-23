---
title: Fix emit unimplemented
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:54:35.299660+02:00\""
closed-at: "2026-01-24T00:12:23.920657+02:00"
---

In src/backends/aarch64/emit.zig:432, replace @panic with error return. List unimplemented instruction types. Deps: none. Verify: zig build test
