---
title: Add GOT-indirect external name loading
status: open
priority: 2
issue-type: task
created-at: "2026-01-07T22:30:39.290141+02:00"
---

File: src/backends/aarch64/emit.zig - Add emitLoadExtNameGot for GOT-indirect symbol access. Sequence: ADRP Xd, symbol@GOTPAGE21 + LDR Xd, [Xd, #symbol@GOT_LO12_NC]. This loads the symbol address FROM the GOT, not the symbol itself. Required for PIC code accessing external functions/data. Add R_AARCH64_ADR_GOT_PAGE21 and R_AARCH64_LD64_GOT_LO12_NC relocations. Depends on hoist-8024f229ae156faf.
