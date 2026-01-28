---
title: Add ARM64 LL/SC atomic loop lowering
status: closed
priority: 2
issue-type: task
created-at: "2026-01-03T16:05:50.369620+02:00"
closed-at: "2026-01-04T04:49:03.132655+02:00"
---

File: src/backends/aarch64/isle_helpers.zig, lower.isle - Infrastructure READY: LDXR/STXR instructions exist (inst.zig:617-723), VCode CFG/blocks complete, branch support complete - Add helpers to generate LL/SC loops: loop: LDAXR dst,[addr] | op temp,dst,src | STLXR status,temp,[addr] | CBNZ status,loop - For atomic_cas: loop: LDAXR dst,[addr] | CMP dst,expected | B.ne success | STLXR status,replacement,[addr] | CBNZ status,loop | success: - Est 150-200 LOC - Depends: LSE helpers (to have fallback) - Accept: atomic_rmw/atomic_cas lower to LL/SC loops
