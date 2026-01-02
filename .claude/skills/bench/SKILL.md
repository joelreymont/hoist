# Benchmarking Skill

## When to Use

Activate when user:
- Asks about decoder performance
- Wants to benchmark throughput
- Compares performance against BN built-in
- Mentions "instructions per second" or "MB/s"
- Is optimizing hot paths

## Dixie Benchmark Command

```bash
zig build run -- bench <bytecode.dx> <binary>
zig build run -- bench x86_64.dx test_binaries/x86_64_aligned.bin
```

## Metrics

| Metric | Description |
|--------|-------------|
| Instructions/sec | Decode throughput |
| MB/s | Byte processing rate |
| Ratio | Dixie / BN built-in (target: >80%) |

## Reference Comparisons

| Dixie Arch | BN Built-in |
|------------|-------------|
| ARM4_le | armv7 |
| mips32be | mips32 |
| ppc_32_be | ppc |

## Hot Path Rules

When optimizing decoder performance:

- **ZERO allocations** in decode path
- **ZERO bounds checks** - use unchecked access with SAFETY comments
- Fixed arrays, not dynamic allocation
- Copy types, stack allocation
- `inline fn` for hot paths

## Profiling Approach

1. Run benchmark to establish baseline
2. Profile with `instruments` or `perf`
3. Identify hot spots
4. Apply optimizations
5. Re-benchmark to verify improvement

## Performance Targets

- 80%+ of BN built-in performance is acceptable
- Parity or better is the goal
