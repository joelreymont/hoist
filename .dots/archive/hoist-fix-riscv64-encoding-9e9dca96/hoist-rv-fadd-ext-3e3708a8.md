---
title: RV fadd ext
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-05T01:20:23.772029+01:00\""
closed-at: "2026-02-05T18:46:05.733340+01:00"
close-reason: Add fadd extractor/export
---

src/generated/isle/riscv64_lower_generated.zig:15576 extractor_fadd returns error.Unimplemented; cause: missing extern extractor mapping for fadd; fix: implement fadd_ext in src/dsl/isle/ir_externs.zig (and export from src/backends/riscv64/isle_impl.zig), ensure decision-tree probing doesn't error; test: zig build test (riscv64_encoding)
