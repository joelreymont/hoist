# Hoist

A Zig port of [Cranelift](https://github.com/bytecodealliance/wasmtime/tree/main/cranelift), a fast and secure code generator for WebAssembly and native code.

## Features

- **Fast compilation**: Optimized for compilation speed while generating good code
- **Multiple backends**: x86-64 and AArch64 support
- **Verification**: Built-in IR verification for correctness
- **Optimization**: ISLE-based pattern matching for peephole optimizations
- **Safety**: Written in Zig with strong type safety guarantees

## Architecture

```
IR → Optimization → ISLE Lowering → VCode → Register Allocation → Machine Code
```

Key components:
- **IR**: SSA-based intermediate representation with strong typing
- **ISLE**: Domain-specific language for instruction selection rules
- **VCode**: Virtual register representation before allocation
- **Backends**: Target-specific code emission (x64, aarch64)

## Quick Start

### Build

```bash
zig build
```

### Run Tests

```bash
zig build test
zig build test-integration
```

### Run Benchmarks

```bash
zig build bench
```

### Run Fuzzers

```bash
zig build fuzz
```

## Usage Example

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

    try sig.params.append(allocator, hoist.types.Type{ .int = .{ .width = 32 } });
    try sig.params.append(allocator, hoist.types.Type{ .int = .{ .width = 32 } });
    try sig.returns.append(allocator, hoist.types.Type{ .int = .{ .width = 32 } });

    // Create function
    var func = try hoist.function.Function.init(allocator, "add", sig);
    defer func.deinit();

    // Build IR (see examples/ for complete code)
    // ...

    // Compile to machine code
    var ctx = hoist.context.ContextBuilder.init(allocator)
        .target(.x86_64, .linux)
        .optLevel(.speed)
        .verify(true)
        .optimize(true)
        .build();

    const code = try ctx.compileFunction(&func);
    defer code.deinit(allocator);

    // code.buffer contains executable machine code
}
```

See `examples/` for complete working examples.

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
