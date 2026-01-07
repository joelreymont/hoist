---
title: Add ssub_overflow_bin lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T08:29:41.820968+02:00"
closed-at: "2026-01-06T08:46:46.289782+02:00"
---

File: compile.zig. Lower ssub_overflow_bin to SUBS+SBCS sequence for multi-word subtraction. Emit SUBS for low word (sets borrow), SBCS for high word (consumes borrow). Returns ValueRegs with result+borrow. Depends on: SBCS instruction variant. ARM64: SUBS+SBCS. Effort: 25 min.
