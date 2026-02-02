---
title: Detect AArch64 features
status: open
priority: 2
issue-type: task
created-at: "2026-02-02T21:35:56.806487+01:00"
blocks:
  - hoist-wire-multi-return-65d02a73
---

Context: src/backends/aarch64/isa.zig:56 detectNative(); cause: non-macos returns defaults and macOS uses stubbed assumptions; fix: implement platform detection (linux getauxval HWCAP/HWCAP2, macOS sysctl hw.optional.*) and map to Features; deps: none; verification: unit tests gated by target + smoke test via isa features.
