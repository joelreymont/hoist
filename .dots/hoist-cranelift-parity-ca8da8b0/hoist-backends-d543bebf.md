---
title: Backends
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:12.690489+02:00\""
closed-at: "2026-01-14T15:42:57.156485+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: ~/Work/wasmtime/cranelift/README.md:54-60 (x86_64/aarch64/s390x/riscv64 backends + ABIs), /Users/joel/Work/hoist/docs/architecture/06-backends.md:5-18 (backend components), /Users/joel/Work/hoist/src/backends/x64/emit.zig:11-16 (x64 emitter minimal), /Users/joel/Work/hoist/src/backends/x64/lower.isle:1-58 (minimal lowering). Root cause: only aarch64 + bootstrap x64 exist; no s390x/riscv64; x64 incomplete. Fix: complete x64 backend and add s390x/riscv64 backends with full lowering/emit/ABI/tests. Why: match Cranelift backend coverage.
