---
title: Implement AAPCS HVA arg mapping
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:25:47.328124+01:00\""
closed-at: "2026-02-06T21:28:12.162364+01:00"
close-reason: Added HVA register/stack arg mapping and coverage
---

src/machinst/abi.zig:352-356 currently returns error.UnsupportedHVA for struct-class hva. Implement HVA argument placement in consecutive V regs and full-aggregate stack spill fallback matching HFA behavior. Add tests for register and spill cases in src/machinst/abi.zig tests section. Depends on existing classifyStruct HVA logic in src/backends/aarch64/abi.zig. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures.
