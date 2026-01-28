---
title: Implement x64 Inst + addressing modes
status: closed
priority: 1
issue-type: task
created-at: "2026-01-04T21:00:19.010744+02:00"
closed-at: "2026-01-05T11:16:32.671406+02:00"
---

Hoist x64 backend is minimal; src/backends/x64/inst.zig:12-13 notes a bootstrap-only Inst set. Cranelift defines full x64 insts and operand/addressing-mode types in ~/Work/wasmtime/cranelift/codegen/src/isa/x64/inst/mod.rs:1-40 and inst/args.rs:1-200. Root cause: inst/args/AMode/RegMem types and most Inst variants not ported. Fix: port inst operand types + Inst enum from Cranelift, update Hoist inst.zig formatters, and wire into lowering/emit.
