---
title: Verify istore8 lowering
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-06T10:12:57.565830+01:00\\\"\""
closed-at: "2026-02-06T10:14:46.388640+01:00"
close-reason: Added AArch64 istore8->STRB lowering regression test
---

Context: src/codegen/compile.zig:4786; cause: ensure istore8 lowers to AArch64 STRB; fix: adjust lowering/inst selection if incorrect; deps: none; verification: add AArch64 store8 test + zig build test
