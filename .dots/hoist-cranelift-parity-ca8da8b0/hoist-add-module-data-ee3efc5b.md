---
title: Add module data
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.653203+02:00\""
closed-at: "2026-01-23T19:00:06.268735+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/module/README.md:9-15
Root cause: no data object support in module layer.
Fix: add data definitions, relocations, and symbol exports.
Why: module parity and linking.
Deps: Add module api.
Verify: data object tests.
