---
title: Audit AArch64 spill/reload path
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T11:02:54.843191+01:00\""
closed-at: "2026-02-06T11:09:08.648096+01:00"
close-reason: Added fail-fast guard and regression test for unmapped spilled vregs in linear-scan spill insertion.
---

src/backends/aarch64/isa.zig:490,545,567 linear-scan spill/reload currently skips spilled vregs when getPhysReg(vreg) is null after spill. Fix spill/reload insertion to preserve values across instruction boundaries; add regression test. Depends on hoist-integrate-regalloc2-8f36d248. Est: 45m
