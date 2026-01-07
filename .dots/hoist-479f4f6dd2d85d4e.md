---
title: Port KnownSymbol enum for symbol resolution
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T09:50:18.233571+02:00"
closed-at: "2026-01-05T09:54:41.975359+02:00"
---

File: Create src/ir/known_symbol.zig from cranelift/codegen/src/ir/known_symbol.rs:6-31. KnownSymbol enum (~6 variants) for well-known runtime symbols. Small module. Root cause: symbol resolution helpers missing. Fix: Port KnownSymbol enum for stack limit checks and other well-known symbols.
