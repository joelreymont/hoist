---
title: Implement return_call argument marshaling
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:29:36.307571+02:00\""
closed-at: "2026-01-08T12:45:42.227607+02:00"
---

File: src/backends/aarch64/isle_impl.zig:1903 - For return_call, marshal arguments to match callee ABI before tail jump. Load arguments into correct registers (x0-x7, v0-v7). If args exceed registers, write to caller's stack frame (which we're about to pop). Must match ABI calling convention exactly. Part of hoist-47cc3973f3c9bd63.
