---
title: Fix ISLE parser errors
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-03T11:49:19.774872+01:00\""
closed-at: "2026-02-03T11:55:33.627558+01:00"
close-reason: Make parser error sets explicit
---

File: src/dsl/isle/parser.zig:431-463; cause: mutual recursion (parsePattern <-> parsePatternAtom) uses inferred error sets => Zig 'unable to resolve inferred error set' when compiling tools/isle_compiler.zig; fix: introduce explicit error set type for Parser parse fns (pattern/expr/defs) and use it in signatures; why: unblock 'zig build' ISLE generation and keep compiler buildable.
