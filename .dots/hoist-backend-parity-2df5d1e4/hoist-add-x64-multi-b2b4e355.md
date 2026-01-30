---
title: Add x64 multi-return ABI
status: open
priority: 2
issue-type: task
created-at: "2026-01-30T11:09:54.370488+01:00"
---

Context: src/backends/x64/abi.zig (return classification) and src/generated/x64_lower_generated.zig; cause: multi-return not classified or lowered; fix: implement System V ABI return classification + lowering for up to 2 GPR/FP regs; deps: Fix x64 float return; verification: new e2e_jit multi-return test under x64
