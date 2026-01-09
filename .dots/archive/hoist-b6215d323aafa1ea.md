---
title: Research x86 SIMD opcodes for AArch64 relevance
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-09T07:48:06.513161+02:00\""
closed-at: "2026-01-09T07:54:31.763937+02:00"
---

Check if X86Cvtt2dq (convert with truncation to dq) and X86Pmaddubsw (multiply-add unsigned/signed bytes) have AArch64 NEON equivalents. Document findings: likely N/A for AArch64-only backend. Files: docs/x86-simd-opcodes.md (new). Pure research, ~20 min.
