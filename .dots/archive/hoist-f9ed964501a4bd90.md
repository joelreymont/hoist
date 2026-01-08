---
title: Implement TLS IE model (Initial Exec)
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-08T11:46:25.655781+02:00\""
closed-at: "2026-01-08T11:59:19.729071+02:00"
---

File: src/backends/aarch64/isle_helpers.zig. Add tls_init_exec() function. Pattern: ADRP + LDR from GOT TLS entry. Similar to emitLoadExtNameGot(). Add lowering rule in lower.isle. Dependencies: TLS relocations, symbol classification. Effort: <30min
