---
title: Add exception tables + unwind + user stack maps
status: closed
priority: 1
issue-type: task
created-at: "2026-01-04T21:01:08.116993+02:00"
closed-at: "2026-01-05T11:21:56.339749+02:00"
---

Cranelift exception tables in ~/Work/wasmtime/cranelift/codegen/src/ir/exception_table.rs:1-160, unwind info in codegen/src/isa/unwind.rs:1-160, and user stack maps in ir/user_stack_maps.rs:1-120; Hoist has no exception_table/user_stack_maps and only aarch64 unwind stub (src/backends/aarch64/unwind.zig). Root cause: EH/GC metadata pipeline not ported. Fix: add IR tables, propagate through codegen, emit unwind info for x64/aarch64, and plumb stack map metadata in MachBuffer.
