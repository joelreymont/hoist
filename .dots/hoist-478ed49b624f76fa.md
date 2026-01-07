---
title: "P2.9.3: Add base store patterns"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-04T14:10:38.145114+02:00"
closed-at: "2026-01-04T14:11:22.572771+02:00"
---

File: src/backends/aarch64/lower.isle - Add store patterns for all types (I8/I16/I32/I64/I128/F*/V*). Pattern: (store flags value address offset) => aarch64_store*/aarch64_fpustore*. Cranelift:2735-2785.
