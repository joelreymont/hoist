---
title: Native detect
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:27.332796+02:00\""
closed-at: "2026-01-14T15:42:57.183924+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: ~/Work/wasmtime/cranelift/native/README.md:1-3 (host autodetect), /Users/joel/Work/hoist/src/context.zig:161-174 (targetNative uses builtin only). Root cause: no CPU feature detection or ISA flags. Fix: implement native CPU feature detection and surface flags in Context/Target. Why: parity with cranelift-native.
