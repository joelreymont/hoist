---
title: Add SSA builder struct
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:50:58.761662+02:00\""
closed-at: "2026-01-24T17:20:03.488698+02:00"
---

Create src/ir/ssa_builder.zig with SSABuilder struct. Tracks variable defs per block, handles incomplete phis. Match Cranelift design. Deps: none. Verify: zig build test
