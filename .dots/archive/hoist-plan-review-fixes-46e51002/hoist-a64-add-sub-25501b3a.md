---
title: A64 add/sub imm
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-05T01:20:18.967431+01:00\\\"\""
closed-at: "2026-02-05T18:45:55.230518+01:00"
close-reason: Add/sub imm range handling
---

src/backends/aarch64/isle_impl.zig:~1445; cause: aarch64_global_value uses Imm12 for Inst.add_imm/sub_imm but inst fields are u16; fix: emit add_imm/sub_imm only for abs(offset)<=4095 using u16, else materialize imm in reg + add_rr; proof: zig build test compile passes
