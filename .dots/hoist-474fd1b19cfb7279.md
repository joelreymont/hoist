---
title: "ISLE: Zig codegen"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:06.330629+02:00\""
closed-at: "\"2026-01-01T16:21:28.370836+02:00\""
close-reason: Completed ISLE Zig codegen (~327 LOC) - basic code generator for ISLE rules, emits match functions with pattern/expression handling with all tests passing
blocks:
  - hoist-474fd1b18c78568b
---

src/dsl/isle/codegen.zig (~800 LOC)

CRITICAL: Adapt existing codegen_zig.rs from Cranelift!

Port from: cranelift/isle/isle/src/codegen_zig.rs (ALREADY EXISTS!)

Generates Zig code from compiled trie:
- Match functions with switch statements
- Constructor calls for RHS expressions
- Let bindings as Zig locals
- Extractor calls

Generated code structure:
  pub fn lower(ctx: *LowerCtx, inst: Inst) ?MachInst {
      switch (ctx.get_opcode(inst)) {
          .iadd => {
              const x = ctx.get_arg(inst, 0);
              const y = ctx.get_arg(inst, 1);
              return x64_add(ctx, x, y);
          },
          // ...
      }
  }

Key advantage: We can run the Rust ISLE compiler first to bootstrap!
