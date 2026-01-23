---
title: Add module api
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.606434+02:00\""
closed-at: "2026-01-23T15:08:57.886893+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/module/README.md:1-15, src/context.zig:61-88
Root cause: no module-level API for multi-function compilation.
Fix: add src/module/module.zig with Module interface, declare/define/finish.
Why: match cranelift-module API.
Deps: none.
Verify: module unit tests.
