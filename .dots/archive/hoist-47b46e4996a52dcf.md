---
title: Generate argument moves in prologue
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:02:10.265777+02:00"
closed-at: "2026-01-06T22:43:07.462850+02:00"
---

File: src/backends/aarch64/abi.zig - In emitPrologue, after frame setup, generate moves from ArgLocation to vreg for each parameter. Register: emit MOV vreg, Xn. Stack: emit LDR vreg, [fp, #offset]. RegisterPair: emit 2 MOVs. Dependencies: hoist-47b46dd83cc19eac, hoist-47b46201fe9355b0.
