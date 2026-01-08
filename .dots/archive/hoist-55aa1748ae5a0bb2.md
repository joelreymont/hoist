---
title: Add TLS relocations to object emission
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-07T22:28:54.897745+02:00\""
closed-at: "2026-01-08T12:30:53.296247+02:00"
---

Files: src/codegen/object.zig or relocation handling - Add TLS-specific relocations: R_AARCH64_TLSDESC_ADR_PAGE21, R_AARCH64_TLSDESC_LD64_LO12, R_AARCH64_TLSDESC_ADD_LO12, R_AARCH64_TLSDESC_CALL. These tell linker to set up TLS descriptor. Must emit in correct sequence for each TLS access. Depends on hoist-c336d84b4151793a.
