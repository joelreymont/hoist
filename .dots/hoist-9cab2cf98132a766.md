---
title: Add register coalescing test
status: open
priority: 2
issue-type: task
created-at: "2026-01-08T20:06:24.997340+02:00"
---

File: tests/e2e_jit.zig. Create function with obvious copy chain: a=input, b=a, c=b, use c. Verify coalescing eliminates MOVs. Check disassembly has 0 or 1 MOV instead of 2-3. Verify correctness of result. ~20 min.
