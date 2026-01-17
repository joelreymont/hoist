### Reference
- Cranelift: `~/Work/wasmtime/cranelift/`
- Parity plan: `~/.claude/plans/fuzzy-sniffing-shamir.md` (261 dots)
- Status: `docs/COMPLETION_STATUS.md`

### Tests
28 files, 325+ cases. Key: `tests/e2e_jit.zig`, `tests/aarch64_tls.zig`, `tests/fp_special_values.zig`

### Entry Points
| Feature | File | Lines |
|---------|------|-------|
| TLS | `isle_helpers.zig` | 2179-2271 |
| FP const | `isle_helpers.zig` | 5562-5625 |
| Tail call | `isle_helpers.zig` | 2769-2793 |
| Varargs | `abi.zig` | 251-323 |

### Exports
- Types: `hoist.types.Type`
- Sig: `hoist.function.signature`
- Imm64: `.new()` not `.from()`

### ISLE Pipeline
1. ISLE lower → MachInst with **vregs**
2. Regalloc → assigns pregs
3. Rewrite vregs→pregs in `compile.zig`
4. Emit → machine code

New instructions: `isle_impl.zig` → `inst.zig` → `getOperands()` → `emitAArch64WithAllocation()` → `emit.zig`

### Code Rules
- No `@panic`, use `!` errors
- No error masking: `catch unreachable` FORBIDDEN
- Prefer stdlib: `std.bit_set`, `std.HashMap`
- Import once: `const types = @import("type.zig");`
- Allocator first param
- Batch append: `appendSlice(&items)`
- Labeled switch for state machines
