### Reference
- Cranelift source: `~/Work/wasmtime/cranelift/`
- Zig 0.15 API changes: `docs/zig-0.15-io-api.md`
- Project status: `docs/COMPLETION_STATUS.md`

### Test Status
- **28 test files** with **325+ test cases** passing
- Test suite registered in `build.zig` (lines 80-220+)
- Key test files:
  - `tests/e2e_jit.zig` - End-to-end JIT compilation (including 40+ live value spilling test)
  - `tests/aarch64_tls.zig` - TLS Local-Exec model (small/large/zero offsets)
  - `tests/fp_special_values.zig` - IEEE 754 special values (NaN, Inf, signed zeros)
  - `tests/aarch64_varargs.zig` - 50+ varargs tests in `src/backends/aarch64/abi.zig`
  - `tests/e2e_branches.zig` - Control flow and branch instructions

### Key Implementation Entry Points

#### TLS (Thread-Local Storage)
**Location**: `src/backends/aarch64/isle_helpers.zig`
- Local Exec: line 2179 (`aarch64_tls_local_exec`)
- Initial Exec: line 2224 (`aarch64_tls_initial_exec`)
- General Dynamic: line 2271 (`aarch64_tls_general_dynamic`)
- All three models fully implemented with proper relocations

#### FP Constant Loading
**Location**: `src/backends/aarch64/isle_helpers.zig` lines 5562-5625
- `aarch64_f32const` / `aarch64_f64const` constructors
- FMOV immediate optimization for encodable values
- Constant pool fallback for special values (NaN, Inf, etc.)
- PC-relative literal loading

#### Tail Calls
**Location**: `src/backends/aarch64/isle_helpers.zig`
- BR emission: line 2769 (register indirect)
- B emission: line 2793 (direct branch)
- Frame deallocation infrastructure exists
- **Note**: Argument marshaling not yet implemented (tracked in dots)

#### VaList (Varargs)
**Location**: `src/backends/aarch64/abi.zig` lines 251-323
- Complete AAPCS64-compliant implementation
- GP and FP register save areas
- Stack overflow handling
- 50+ comprehensive tests

#### Call Returns
**Location**: `src/backends/aarch64/isle_helpers.zig` line 3019
- Currently returns single X0 register only
- **Note**: Multi-return and FP return marshaling tracked in dots

### Module Export Paths
- **Types**: `hoist.types.Type` (NOT `hoist.Type`)
- **Signature**: `hoist.function.signature` (made public in `src/ir/function.zig:6`)
- **Imm64 API**: Use `.new()` constructor (NOT `.from()`)

### ISLE (Instruction Selection Lowering Expressions)

**CRITICAL: ISLE is for IR→MachInst lowering ONLY, NOT for register allocation or rewriting.**

Pipeline architecture:
1. **ISLE lowering** (`src/backends/*/lower.isle`) - Pattern-match IR ops to MachInst with **virtual registers**
2. **Register allocation** (`src/regalloc/`) - TrivialAllocator assigns physical registers to vregs
3. **VReg→PReg rewriting** (`src/codegen/compile.zig`) - Explicit rewriting of all instruction operands
4. **Emission** (`src/backends/*/emit.zig`) - Encode instructions to machine code

**Never confuse ISLE with register allocation:**
- ISLE helpers (e.g., `aarch64_lsl_rr` in `isle_impl.zig`) emit instructions with **virtual registers only**
- `ctx.allocOutputReg()` and `ctx.getValueReg()` return virtual registers
- Physical register assignment happens LATER in the pipeline
- VReg→PReg rewriting is manual, per-instruction in `emitAArch64WithAllocation()`

**When implementing new instructions:**
1. Add ISLE constructor in `isle_impl.zig` - use vregs only
2. Add instruction variant to `inst.zig` - fields are `Reg` (can be virtual or physical)
3. Add operand collection to `inst.zig::getOperands()` - for register allocator
4. Add vreg→preg rewriting to `compile.zig::emitAArch64WithAllocation()` - manual per instruction
5. Add emission to `emit.zig` - expects physical registers only

**Cranelift comparison:**
- Cranelift uses regalloc2 which replaces vregs with "pinned vregs" (indices 0-191 = physical)
- We use TrivialAllocator which returns `Allocation` (separate from instruction)
- Cranelift queries allocation during `emit()`, we rewrite before `emit()`
- Both approaches are correct; ours requires explicit rewriting for each instruction type

### Code Quality
- No dead code
- No `@panic` - use `!` error returns
- Type safety - enums, tagged unions, comptime
- Named constants, no magic numbers
- **Prefer Zig stdlib over blind porting**: Carefully consider `std.bit_set`, `std.HashMap`, `std.ArrayList`, etc. before reimplementing Rust data structures; add thin wrappers only when necessary

### Zig Idioms

**Import once, namespace access:**
```zig
// WRONG: Multiple imports from same module
const Type = @import("type.zig").Type;
const Primitive = @import("type.zig").Primitive;

// RIGHT: Import module once, use namespace
const types = @import("type.zig");
// Then use: types.Type, types.Primitive
```

**Allocator first:**
Allocator is ALWAYS the first argument:
```zig
// RIGHT
pub fn init(allocator: std.mem.Allocator) Self { ... }

// WRONG
pub fn init(config: Config, allocator: std.mem.Allocator) Self { ... }
```

**ArrayList batch append:**
```zig
// WRONG: Append items one by one
try list.append(allocator, a);
try list.append(allocator, b);

// RIGHT: Create static array, appendSlice once
const items = [_]T{ a, b, c };
try list.appendSlice(allocator, &items);
```

**Error handling - NEVER MASK ERRORS:**
ALL error-masking patterns are FORBIDDEN:
```zig
// FORBIDDEN:
foo() catch unreachable;
foo() catch return;
foo() catch return null;
foo() orelse unreachable;

// RIGHT - Always propagate errors
const result = try foo();
```
Functions that call fallible operations MUST return error unions.

**The only acceptable use of `unreachable`:**
- Switch cases that are logically impossible (exhaustive enum after filtering)
- Array indices proven in-bounds by prior checks
- Never for "this shouldn't fail" - if it can fail, propagate the error

**State machines - labeled switch pattern:**
Use labeled switch for complex control flow instead of while-switch:
```zig
// RIGHT: Labeled switch pattern
state: switch (state) {
    .start => { state = .middle; continue :state; },
    .middle => { state = .end; continue :state; },
    .end => break,
}

// WRONG: while-switch
while (true) {
    switch (state) {
        .start => state = .middle,
        .middle => state = .end,
        .end => break,
    }
}
```