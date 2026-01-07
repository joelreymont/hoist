---
title: Port alias_analysis.rs module
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T09:38:21.343916+02:00"
closed-at: "2026-01-05T11:24:40.817520+02:00"
---

File: Create src/codegen/alias_analysis.zig from cranelift/codegen/src/alias_analysis.rs:1-120. Implements memory alias analysis for optimization passes. Tracks memory effects (load/store/call) and determines when two memory operations can alias. Used by GVN and LICM. Root cause: optimization analysis missing. Fix: Port AliasAnalysis struct with query methods, integrate with optimize.zig.
