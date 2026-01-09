---
title: Implement emission pipeline PC tracking
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T06:07:58.350225+02:00"
---

File: src/codegen/compile.zig, src/machinst/mach_buffer.zig. Need to track instruction->PC and block->PC mappings during emission. Required for LSDA wiring (mapping try_call PCs to landing pad PCs). Add inst_offsets: HashMap(Inst, u32) and block_offsets: HashMap(Block, u32) to MachBuffer or emission context. Populate during emit() calls. Expose via API for generateEhFrame().
