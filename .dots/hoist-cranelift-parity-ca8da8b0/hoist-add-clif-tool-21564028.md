---
title: Add clif tool
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.682659+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/reader/README.md:1-3
Root cause: no CLI for reading/writing IR text.
Fix: add tools/clif_util.zig to parse/print IR and run filetests.
Why: parity with cranelift-reader tooling.
Deps: Add ir parser, Add ir printer.
Verify: CLI smoke tests.
