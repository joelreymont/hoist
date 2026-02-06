---
title: Fix div/rem immediate lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T20:37:54.446638+01:00\""
closed-at: "2026-02-06T20:41:18.373790+01:00"
close-reason: Completed
---

Context: /Users/joel/Work/hoist/src/codegen/compile.zig:4240,4291,4380,4463 currently materializes divisors with movz truncating to 16 bits for udiv_imm/urem_imm/sdiv_imm/srem_imm. Cause: fallback immediate paths lose high bits and miscompile large immediates. Fix: materialize full-width constants with mov_imm in all fallback paths; add lowering tests proving full immediates are preserved for each opcode. Deps: none. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures
