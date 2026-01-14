---
title: Regalloc2
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:06:29.619325+02:00\""
closed-at: "2026-01-14T15:42:57.189185+02:00"
close-reason: split into small dots under hoist-cranelift-parity
---

Context: ~/Work/wasmtime/cranelift/README.md:46-50 (regalloc fuzzing), /Users/joel/Work/hoist/src/machinst/regalloc.zig:13-15 (linear scan placeholder), /Users/joel/Work/hoist/src/machinst/compile.zig:117-147 (TODO regalloc2), /Users/joel/Work/hoist/src/backends/aarch64/isa.zig:255-288 (regalloc2 stub). Root cause: regalloc2 not integrated. Fix: implement regalloc2 algorithm and integrate into compile pipeline; add verification tests. Why: parity with Cranelift allocator quality.
