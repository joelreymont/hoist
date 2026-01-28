---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:17.117594+02:00"
closed-at: "2026-01-01T09:05:17.935779+02:00"
close-reason: Replaced with correctly titled task
---

Port layout/CFG from cranelift/codegen/src/ir/layout.rs + function.rs (~1500 LOC). Create src/ir/layout.zig with block ordering, instruction layout, and src/ir/cfg.zig with control flow graph. Depends on: entities (hoist-474de7656791a5b2), entity maps (hoist-474de68d56804654), bforest (hoist-474de6c75becbce7). Files: src/ir/layout.zig, cfg.zig. Block/instruction ordering and CFG analysis.
