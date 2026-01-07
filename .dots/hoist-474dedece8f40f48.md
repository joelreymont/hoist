---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:44:50.044158+02:00"
closed-at: "2026-01-01T08:53:10.931684+02:00"
close-reason: Deferred - ARM64 only initially, x64 later
---

Port x64 encoder from cranelift/codegen/src/isa/x64/inst/emit.rs (~3000 LOC). Create src/backends/x64/emit.zig with REX prefix, ModR/M, SIB, immediate encoding, all instruction encodings. Depends on: x64 inst (hoist-474ded8520631fd3), buffer (hoist-474debc1934bfa6e). Files: src/backends/x64/emit.zig, emit_test.zig. Binary encoding for all x64 instructions.
