---
title: "quality: benchmarks"
status: closed
priority: 3
issue-type: task
created-at: "\"2026-01-01T11:03:00.388321+02:00\""
closed-at: "\"2026-01-01T17:20:45.582619+02:00\""
close-reason: "\"completed: benchmark infrastructure - bench/{compile_fib,compile_large}.zig (288 LOC) for measuring compile time, throughput, and code size\""
blocks:
  - hoist-474fdc1165679cee
---

bench/ infrastructure

Benchmarks:

Compile time:
- Functions of various sizes
- Measure: IR->binary latency
- Compare vs Cranelift Rust

Throughput:
- Instructions compiled per second
- Memory usage during compilation

Code quality:
- Output code size
- Compare vs LLVM -O2
- Runtime performance of generated code

Benchmark suite:
- bench/compile_fib.zig
- bench/compile_mandelbrot.zig
- bench/compile_large.zig

Targets:
- Compile time: <2x Cranelift acceptable
- Code size: within 10% of Cranelift
