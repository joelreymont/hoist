---
title: CAS atomic operations
status: closed
priority: 2
issue-type: task
created-at: "2026-01-07T15:24:11.099837+02:00"
closed-at: "2026-01-07T15:42:54.562696+02:00"
---

ELEVATED TO P1 (oracle: required for 128-bit atomics). Implement CASA/CASB/CASH/CASL variants. Implement CASP (compare-and-swap pair) for 128-bit. Handle acquire/release semantics. Fallback to LL/SC when LSE unavailable. Test: atomic_cas for u32, u64, u128. Phase 1.18, Priority P1
