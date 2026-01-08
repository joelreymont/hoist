---
title: Wire LSDA to FDE during compilation
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T22:32:04.855572+02:00"
---

File: src/codegen/compile.zig. In generateEhFrame(), scan function for try_call instructions. For each try_call, get PC offset from MachBuffer, get landing_pad block PC. Create LSDA, addCallSite(try_call_offset, 4, landing_pad_offset). Attach LSDA to FDE before encoding. Need access to block->PC mapping. ~20 min.
