---
title: Fix e2e JIT tests
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-24T00:44:21.295550+02:00\""
closed-at: "2026-01-24T00:53:31.146537+02:00"
---

4 tests failing in e2e_jit.zig:
1. 'compile and execute return constant i32' - error at makeExecutable but prints correct output
2. 'compile and execute i32 add' - same issue
3. 'compile and execute i64 multiply' - same issue  
4. 'register spilling with 40+ live values' - OutOfRegisters at linear_scan.zig:315

Issue #1-3: Tests print debug output successfully (showing correct machine code and execution) but then fail at makeExecutable line. This is likely a test harness/error reporting issue, not actual JIT failure. Machine code looks correct: loads correct values, proper prologue/epilogue.

Issue #4: Real bug - linear scan allocator runs out of registers. Test creates 40 live values which exceeds available registers. Allocator should spill but hits 'No suitable spill candidate' case.

Root cause investigation needed:
- Check if makeExecutable is actually failing or if error attribution is wrong
- For OutOfRegisters: debug why spill candidate selection fails
- May need to increase scratch register pool or fix spill heuristic

Files: tests/e2e_jit.zig:240,310,389,536 src/regalloc/linear_scan.zig:315
