---
title: Implement icmp integer comparison
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T10:25:56.808725+02:00"
closed-at: "2026-01-06T10:33:53.800313+02:00"
---

File: src/codegen/compile.zig - Add lowering for icmp operation. Use SUBS/ADDS to set flags, then CSET with appropriate condition code (eq/ne/lt/le/gt/ge/ult/ule/ugt/uge). Maps to binary instruction data. Critical P0 operation for control flow.
