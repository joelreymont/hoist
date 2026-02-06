---
title: Validate vector load/store immediate offsets
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:05:19.033369+01:00\""
closed-at: "2026-02-06T22:07:41.680237+01:00"
close-reason: Added unsigned imm12 checks for VLDR/VSTR plus regression/encoding tests
---

src/backends/aarch64/emit.zig: emitVldr/emitVstr currently use @divExact+@intCast without explicit range/alignment validation, which can trap or mis-encode. Reuse unsigned imm12 validator with scale by FP size, add regression tests for OffsetOutOfRange/OffsetNotAligned and max encodings. Depends on hoist-validate-pair-load-3025711f. Est: 25m
