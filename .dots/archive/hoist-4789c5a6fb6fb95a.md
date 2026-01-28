---
title: "T2.3a: Implement vector shift immediates"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T08:08:32.410492+02:00"
closed-at: "2026-01-04T08:14:09.386520+02:00"
---

Files: src/backends/aarch64/lower.isle, isle_helpers.zig. Add ishl/ushr/sshr with iconst immediate for ty_vec128. Benefit: shl vN.T, vM.T, #imm vs dup; shl. 5 rules. 2.5-7.5h.
