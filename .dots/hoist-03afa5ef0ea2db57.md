---
title: Mark x86 opcodes as N/A in gap analysis
status: open
priority: 2
issue-type: task
created-at: "2026-01-09T07:48:06.517879+02:00"
---

Update docs/cranelift-gap-analysis.md to clarify X86Cvtt2dq and X86Pmaddubsw are x86-specific, not gaps for AArch64 backend. Adjust IR coverage metric to 186/186 (100%) when excluding platform-specific ops. Files: docs/cranelift-gap-analysis.md:48-60. ~10 min.
