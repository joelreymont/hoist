---
title: Fix regalloc2 class-aware spill allocation
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:01:24.653862+01:00\""
closed-at: "2026-02-06T21:06:36.860509+01:00"
close-reason: Track class metadata, allocate FP/vector correctly, and size spills by class
---

src/machinst/regalloc2/allocator.zig: remove hardcoded integer allocation path and size=8 spills; add class-aware register bank/spill sizing via adapter metadata. src/machinst/regalloc2/api.zig: track vreg class map. src/backends/aarch64/regalloc_bridge.zig: record reg class when extracting operands and convert vreg IDs consistently. Add tests for float register bank and vector spill slot sizing. Depends on PLAN.md section 4.5 spill/reload audit. Est: 30m
