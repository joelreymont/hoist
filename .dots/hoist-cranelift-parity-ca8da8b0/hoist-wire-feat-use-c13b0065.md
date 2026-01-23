---
title: Wire feat use
status: closed
priority: 1
issue-type: task
created-at: "\"2026-01-14T15:42:46.735511+02:00\""
closed-at: "2026-01-23T21:06:13.419784+02:00"
---

Files: src/target/features.zig:60-120, src/backends/aarch64/emit.zig:24-31
Root cause: codegen does not consult feature flags.
Fix: gate LSE, SVE, SIMD, and other feature-specific encodings in lowering/emit.
Why: correct codegen on varied CPUs.
Deps: Wire native feat.
Verify: feature-gated encoding tests.
