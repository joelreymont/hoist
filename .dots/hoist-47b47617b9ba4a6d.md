---
title: Implement classifyAggregateArg
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:04:21.215687+02:00"
closed-at: "2026-01-07T06:16:55.182437+02:00"
---

File: src/backends/aarch64/abi.zig - Implement classifyAggregateArg(ty, gpr_idx, fpr_idx). If HFA: return ArgLocation.RegisterSequence([V0+fpr_idx, V1+fpr_idx, ...], count), fpr_idx+=count. If size<=16: return Register(s) or Stack. If size>16: pass pointer in GPR. Dependencies: hoist-47b475a83d35be93.
