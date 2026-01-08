---
title: Use Valgrind or ASan to find allocator corruption
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T06:39:27.910377+02:00"
---

File: tests/e2e_jit.zig - Memory corruption detected by debug allocator at alloc:806. Manifests after ctx.compileFunction() completes. Not in MachBuffer (bounds checking passed). Fixed relocation name leaks but corruption persists. Need ASan/Valgrind to find exact source. Corruption is in allocator metadata (slot_count invalid). Stack shows ___gtxf2 (long double comparison) suggesting allocator bucket corruption.
