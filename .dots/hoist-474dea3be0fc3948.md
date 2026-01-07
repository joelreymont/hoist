---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:48.110598+02:00"
closed-at: "2026-01-01T09:05:17.958483+02:00"
close-reason: Replaced with correctly titled task
---

Adapt existing cranelift/isle/isle/src/codegen_zig.rs (~800 LOC) to Zig port. Create src/dsl/isle/codegen.zig emitting Zig code from ISLE AST. Depends on: sema (hoist-474de9a058740af5), trie (hoist-474de9ddbb8dc284). Files: src/dsl/isle/codegen.zig. Generates Zig matching/construction code from ISLE rules. CRITICAL: This already exists in Rust, just needs adaptation!
