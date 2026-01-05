# Hoist

A Zig port of [Cranelift](https://github.com/bytecodealliance/wasmtime/tree/main/cranelift), a fast and secure code generator for WebAssembly and native code.

## Status

**Work in Progress** - Core infrastructure complete, code generation in development.

Currently implemented:
- ✅ **IR**: SSA-based intermediate representation with full type system
- ✅ **Foundation**: Entity maps, bitsets, control flow graph, dominator trees
- ✅ **Analysis**: Loop detection, dominator frontiers, SSA construction
- ✅ **Optimization**: Basic peephole optimizations, constant folding
- ✅ **Lowering**: VCode generation with basic instruction lowering (iconst, iadd, return)
- ✅ **AArch64**: Minimal instruction set (mov_imm, add_rr, ret)
- ⏳ **Register allocation**: Infrastructure present, algorithm not yet implemented
- ⏳ **Code emission**: Framework in place, machine code generation stubbed
- ⏳ **ISLE compiler**: Parser and runtime stubs, pattern compilation not complete
- ❌ **x86-64**: Instruction definitions present, lowering not implemented

## Architecture

```
IR → Optimization → Lowering → VCode → Register Allocation → Machine Code
                        ↓
                     (ISLE rules - in progress)
```

Current pipeline status:
- **IR**: ✅ SSA-based intermediate representation with strong typing
- **Optimization**: ✅ Basic passes implemented (constant folding, dead code elimination)
- **Lowering**: ✅ Direct lowering for basic instructions (iconst, iadd, return)
- **VCode**: ✅ Virtual register representation before allocation
- **Register Allocation**: ⏳ Infrastructure present, needs implementation
- **Code Emission**: ⏳ Framework in place, needs instruction encoding

## Quick Start

### Build

```bash
# Default (Debug mode)
zig build

# With optimization level
zig build -Doptimize=ReleaseFast
```

Available optimization levels:
- `Debug` - No optimizations, all safety checks enabled (default)
- `ReleaseSafe` - Optimizations enabled, safety checks enabled
- `ReleaseSmall` - Optimize for small binary size
- `ReleaseFast` - Optimize for execution speed, safety checks disabled

### Run Tests

```bash
zig build test
```

Current test status: 396/397 tests passing (99.7%)

Note: End-to-end JIT tests are currently disabled as register allocation and code emission are not yet implemented.

## Usage Example

**Note**: Full compilation pipeline is under development. The example below shows the current API, but machine code emission is not yet complete.

```zig
const std = @import("std");
const hoist = @import("root");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create function signature: fn(i32, i32) -> i32
    var sig = try hoist.signature.Signature.init(allocator);
    defer sig.deinit(allocator);

    try sig.params.append(allocator, hoist.types.Type.I32);
    try sig.params.append(allocator, hoist.types.Type.I32);
    try sig.returns.append(allocator, hoist.types.Type.I32);

    // Create function
    var func = try hoist.function.Function.init(allocator, "add", sig);
    defer func.deinit();

    // Build IR using FunctionBuilder
    var builder = try hoist.builder.FunctionBuilder.init(allocator, &func);
    const entry = try builder.createBlock();
    try builder.switchToBlock(entry);

    const v1 = try builder.iconst(hoist.types.Type.I32, 10);
    const v2 = try builder.iconst(hoist.types.Type.I32, 20);
    const result = try builder.iadd(v1, v2);
    try builder.@"return"(result);

    // Current status: Generates IR and VCode, but not yet executable machine code
    // Register allocation and code emission are in progress
}
```

For working examples, see unit tests in `src/ir/` and `tests/`.

## Documentation

- [Architecture Overview](docs/architecture.md) - Design and implementation
- [IR Reference](docs/ir.md) - Instruction set and types
- [ISLE Tutorial](docs/isle.md) - Pattern matching for lowering
- [Porting Guide](docs/porting.md) - How we ported from Rust Cranelift

## Project Structure

```
src/
  foundation/     - Core data structures (bforest, bitset, entity maps)
  ir/             - Intermediate representation
  dsl/isle/       - ISLE pattern compiler
  machinst/       - Machine instruction abstraction
  backends/       - Target-specific backends (x64, aarch64)
    x64/          - x86-64 instruction encoding and lowering
    aarch64/      - ARM64 instruction encoding and lowering

tests/            - Integration tests
bench/            - Performance benchmarks
fuzz/             - Fuzzing harnesses
docs/             - Documentation
examples/         - Usage examples
```

## Development

### Code Style

- Follow Zig stdlib conventions
- Allocator is always first parameter
- Prefer `try` over `catch` for error propagation
- Use named constants over magic numbers

### Testing

Run all tests:
```bash
zig build test
```

Run specific test file:
```bash
zig test src/ir/function.zig
```

### Benchmarking

```bash
zig build bench
./zig-out/bin/bench_fib
./zig-out/bin/bench_large
```

### Fuzzing

```bash
zig build fuzz
./zig-out/bin/fuzz_compile 10000
./zig-out/bin/fuzz_regalloc 10000
```

## Differences from Cranelift

While maintaining conceptual compatibility, this port makes Zig-idiomatic choices:

- **Memory management**: Explicit allocators instead of Rust's ownership
- **Error handling**: Zig error unions instead of Result<T, E>
- **Data structures**: Zig stdlib collections where appropriate
- **Safety**: Compile-time checks via comptime and type system

See [docs/porting.md](docs/porting.md) for detailed comparison.

## Contributing

Contributions welcome! Areas of interest:

- Additional backends (RISC-V, ARM32)
- ISLE compiler improvements
- Optimization passes
- Test coverage
- Documentation

## License

Apache-2.0 / MIT dual-licensed (matching upstream Cranelift)

## References

- [Cranelift](https://github.com/bytecodealliance/wasmtime/tree/main/cranelift) - Original Rust implementation
- [ISLE](https://github.com/bytecodealliance/wasmtime/tree/main/cranelift/isle) - Instruction Selection Lowering Expressions
- [Zig](https://ziglang.org/) - The Zig programming language
