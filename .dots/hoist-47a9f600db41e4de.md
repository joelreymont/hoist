---
title: Create address mode test suite
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T22:32:42.560329+02:00"
closed-at: "2026-01-07T07:21:33.796703+02:00"
---

File: tests/codegen/aarch64_addr_mode_tests.zig. Test each addressing mode: base+immediate (all offset ranges), base+register, extended register, pre/post-indexed, literal pool. Test LDP/STP pair generation. Test offset legalization (large offsets). Effort: 2-3 days.
