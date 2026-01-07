---
title: Resolve branch target offsets after emission
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.399363+02:00"
closed-at: "2026-01-07T10:42:57.215550+02:00"
---

File: src/machinst/buffer.zig use existing fixup infrastructure
Currently: MachBuffer has fixup support
Need: Generate fixup records during lowering, apply after emission
Implementation: During lowering record fixup for each branch with label, after emission iterate fixups and patch instruction with computed offset
Dependencies: First emit dot
Estimated: 2 days
Test: Test branches to forward/backward labels
