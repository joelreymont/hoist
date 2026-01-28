---
title: Extract operands for memory and branch instructions
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T09:10:15.338055+02:00"
closed-at: "2026-01-07T10:42:57.175907+02:00"
---

File: src/backends/aarch64/inst.zig continue inst_operands()
Part 2 covers: loads, stores, branches, calls (~150 variants)
Special cases: Loads (use base reg, def destination), Stores (use value + base), Branches (use condition regs), Calls (clobber caller-saved, handle args/returns)
Dependencies: Previous regalloc dot
Estimated: 3 days
Test: Test memory/branch operand extraction
