---
title: Validate pair load/store scaled offsets
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T22:02:17.422262+01:00\""
closed-at: "2026-02-06T22:05:03.386322+01:00"
close-reason: Added signed scaled imm7 checks for pair ops and SIMD pair regressions
---

src/backends/aarch64/emit.zig: emitStp/emitLdp/emitStpPre/emitLdpPost and SIMD pair forms currently truncate scaled signed imm7 offsets without range/alignment checks. Add shared signed-scaled imm7 validator, reject out-of-range/unaligned offsets, and add regression tests. Depends on hoist-validate-unsigned-load-ab3d0d48. Est: 30m
