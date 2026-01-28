---
title: "ISLE: compiler driver"
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-01T11:00:06.334531+02:00\""
closed-at: "\"2026-01-01T16:23:55.737849+02:00\""
close-reason: Completed ISLE compiler driver (~203 LOC) - orchestrates lex->parse->sema->codegen pipeline with Source input and CompiledCode output, error handling with all tests passing
blocks:
  - hoist-474fd1b19cfb7279
---

src/dsl/isle/compile.zig (~500 LOC)

Port from: cranelift/isle/isle/src/{lib,compile}.rs

Main entry point:
- compile(sources: []Source) -> Result<CompiledCode>
- Orchestrates: lex -> parse -> sema -> trie -> codegen

Integration with build.zig:
- Custom build step for .isle -> .zig
- Dependency tracking for incremental builds
- Error reporting with source locations

MILESTONE: Can compile .isle files to .zig!

Bootstrap strategy:
1. Initially use Rust cranelift-isle to generate Zig
2. Port ISLE compiler to Zig
3. Self-host: Zig ISLE compiles ISLE rules to Zig
