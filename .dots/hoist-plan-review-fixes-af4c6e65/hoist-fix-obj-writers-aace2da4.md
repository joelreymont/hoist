---
title: Fix Object Writers
status: open
priority: 2
issue-type: task
created-at: "2026-01-29T10:05:45.451607+01:00"
---

Context: src/object/elf.zig:171; cause: writers incomplete and relocs unresolved; fix: implement symbol indices and full emission; deps: hoist-plan-review-fixes-af4c6e65; verification: object file validated with llvm-readobj/otool
