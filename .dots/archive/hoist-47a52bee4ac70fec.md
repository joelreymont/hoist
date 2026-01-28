---
title: Implement getOperands() for add_rr
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T16:49:52.476881+02:00"
closed-at: "2026-01-05T17:01:27.293314+02:00"
---

File: src/backends/aarch64/inst.zig - In getOperands() method, add add_rr case: collector.regUse(self.add_rr.src1); collector.regUse(self.add_rr.src2); collector.regDef(self.add_rr.dst). Pattern: reads src1+src2, writes dst. ~3 LOC.
