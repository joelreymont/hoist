---
title: Add spilling tests
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:03:06.497382+02:00"
closed-at: "2026-01-06T23:42:00.344274+02:00"
---

File: tests/spilling.zig - Test: register pressure forces spill (N+1 live vregs, N physical regs). Verify spill store inserted after def, reload before use. Verify correctness of spilled value. Test: nested spills (spill A, then B, then reload A). Dependencies: hoist-47b47132ecc88615.
