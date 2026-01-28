---
title: "x64: ISLE rules"
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-01T11:01:30.857413+02:00\""
closed-at: "\"2026-01-01T16:58:13.867425+02:00\""
close-reason: "\"completed: src/backends/x64/lower.isle with ISLE rules for arithmetic (iadd/isub/imul), memory (load/store), control flow (jump/brif/return), constants. src/backends/x64/lower.zig with backend integration stubs. All tests pass.\""
blocks:
  - hoist-474fd6bb440a3760
---

src/backends/x64/lower.isle -> lower_generated.zig

Compile x64 ISLE rules (~9k LOC ISLE):
- cranelift/codegen/src/isa/x64/lower.isle
- cranelift/codegen/src/isa/x64/inst.isle

Rule examples:
  (rule (lower (iadd x y))
        (x64_add (put_in_gpr x) (gpr_mem y)))

  (rule (lower (load addr))
        (x64_mov_rm (amode addr)))

Categories:
- Arithmetic lowering
- Memory operations
- Comparisons and branches
- SIMD operations

Generated output:
- lower() function with pattern matching
- Constructor helpers (x64_add, x64_mov, etc.)
