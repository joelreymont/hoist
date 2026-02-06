---
title: Fix AAPCS general struct arg splitting
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:32:22.663749+01:00\""
closed-at: "2026-02-06T21:34:43.601311+01:00"
close-reason: Implemented <=16-byte general struct chunking and spill fallback
---

src/machinst/abi.zig:.general struct branch currently falls through handleRegClass and uses a single integer slot for <=16-byte non-HFA/HVA structs. Implement 8-byte chunk splitting into 1-2 GPR slots with whole-aggregate stack fallback when insufficient registers. Add tests for 16-byte struct in registers and spill when only one GPR remains. Depends on classifyStruct() behavior in src/backends/aarch64/abi.zig. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures.
