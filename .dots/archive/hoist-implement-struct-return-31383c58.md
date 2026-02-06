---
title: Implement struct return slots in ABIMachineSpec
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T21:35:15.293699+01:00\""
closed-at: "2026-02-06T21:37:38.682794+01:00"
close-reason: Added struct return classification in ABIMachineSpec and tests
---

src/machinst/abi.zig:computeRetLocs currently treats struct returns as scalar int/float classes and misses AAPCS struct classifications. Add classifyStruct handling for .hfa/.hva/.general/.indirect (X8 sret pointer) with proper register slot counts. Add AAPCS tests for general struct returns in X0/X1, HVA returns in V0/V1, and indirect returns in X8. Verification: zig build test -j1 --global-cache-dir .zig-global-cache --summary failures.
