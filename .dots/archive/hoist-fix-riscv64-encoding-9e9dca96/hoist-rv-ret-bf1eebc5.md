---
title: RV ret
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-05T01:20:28.374247+01:00\\\"\""
closed-at: "2026-02-05T18:46:10.196277+01:00"
close-reason: Implement rv_ret
---

src/backends/riscv64/isle_impl.zig:379 rv_ret returns error.Unimplemented; cause: lower pipeline needs return/epilogue emission; fix: implement rv_ret constructor to emit ret sequence and update related lowering if needed; test: zig build test (riscv64_encoding)
