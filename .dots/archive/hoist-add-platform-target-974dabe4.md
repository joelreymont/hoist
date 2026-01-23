---
title: Add platform target spec
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:50:32.674164+02:00\""
closed-at: "2026-01-26T08:51:23.484107+01:00"
---

Create src/target.zig with TargetSpec struct: os, arch, features, abi_variant. Used at compile-time to select Darwin/Linux behavior. Deps: none. Verify: zig build test
