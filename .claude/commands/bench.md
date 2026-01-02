Run benchmarks comparing Bebop plugins against BN built-in architectures.

Run: `python3 tools/benchmark.py`

This benchmarks Bebop plugins against BN built-in equivalents:
| Bebop Arch | BN Built-in |
|------------|-------------|
| ARM4_le    | armv7       |
| mips32be   | mips32      |
| ppc_32_be  | ppc         |

Metrics:
- Instructions per second (throughput)
- MB/s processing rate
- Performance ratio (Bebop / BN built-in)

Target: 80%+ performance ratio is acceptable.

For VM core benchmarks (microbenchmarks), run:
```
cargo bench -p bebop-vm-core --bench vm_bench
```

For JIT benchmarks:
```
DYLD_LIBRARY_PATH="/Applications/Binary Ninja.app/Contents/MacOS" cargo bench -p bebop-vm-jit --bench jit_bench
```
