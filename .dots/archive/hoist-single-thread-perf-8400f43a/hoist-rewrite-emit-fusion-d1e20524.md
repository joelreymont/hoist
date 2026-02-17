---
title: Rewrite emit fusion
status: closed
priority: 1
issue-type: task
created-at: "\"2026-02-17T20:38:18.769986+01:00\""
closed-at: "2026-02-17T21:57:19.956132+01:00"
close-reason: "discarded: architecture API coupling caused test-root import failures; no safe retained >=5% gain path"
blocks:
  - hoist-operand-metadata-cache-a3504144
---

Context: src/codegen/compile.zig:6715-6990 and emit paths. Cause: standalone rewrite pass scans full vcode before emission, duplicating traversal and memory traffic. Fix: fuse allocation rewrite into emit path for AArch64 so rewritten regs are consumed directly while preserving relocation/trap correctness. Why: remove full-pass overhead and improve cache locality. Verify: zig build test, e2e JIT tests, bench-gate; keep only >=5% wins with no regressions.
