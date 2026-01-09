---
title: Populate LSDA with actual PC offsets
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T06:23:52.517465+02:00\""
closed-at: "2026-01-09T06:31:28.740606+02:00"
---

File: src/codegen/compile.zig:6891 - Replace placeholder offsets (currently 0) with real PC offsets from MachBuffer. Need to: 1) Get try_call instruction's block, 2) Query buffer.getBlockOffset(try_call_block) for start PC, 3) Get exception_successor block from try_call instruction data, 4) Query buffer.getBlockOffset(exception_successor) for landing pad PC, 5) Pass real offsets to lsda.addCallSite(). Depends on block label binding.
