---
title: Fix Object Writers
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.565588+01:00"
blocks:
  - hoist-wire-isle-lowering-9d324cc5
---

Context: src/object/elf.zig:171; cause: writers incomplete and relocs unresolved; fix: implement symbol indices and full emission; deps: Plan: Review Fixes; verification: object file validated with llvm-readobj/otool
