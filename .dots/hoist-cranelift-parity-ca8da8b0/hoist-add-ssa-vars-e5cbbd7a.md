---
title: Add ssa vars
status: open
priority: 1
issue-type: task
created-at: "2026-01-14T15:42:46.694652+02:00"
---

Files: /Users/joel/Work/wasmtime/cranelift/frontend/README.md:1-5, src/ir/builder.zig:1-120
Root cause: no SSA variable tracking or use_var/def_var API.
Fix: add SSA variable table and Variable type in src/ir/ssa_builder.zig.
Why: frontend SSA construction parity.
Deps: none.
Verify: SSA unit tests.
