---
title: Wire LSDA to FDE with PC mappings
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T06:08:06.531230+02:00"
---

File: src/codegen/compile.zig:6875. Depends on hoist-ba31dd5d2386c2f4. In generateEhFrame(), scan IR function for try_call instructions. For each try_call: get inst PC from inst_offsets, get exception_successor block PC from block_offsets. Create LSDA, call addCallSite(try_call_pc, 4, landing_pad_pc). Attach lsda to FDE before encoding. Pass Function to generateEhFrame/assembleResult.
