---
title: Frontend SSA
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:26.725341+02:00\""
closed-at: "2026-01-14T15:42:57.178740+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: ~/Work/wasmtime/cranelift/frontend/README.md:1-5 (use_var/def_var SSA builder), /Users/joel/Work/hoist/src/ir/builder.zig:37-113 (FunctionBuilder lacks var API). Root cause: no SSA variable front-end helpers. Fix: add variable map + use_var/def_var APIs, tests, and integrate with builder. Why: parity with cranelift-frontend ergonomics.
