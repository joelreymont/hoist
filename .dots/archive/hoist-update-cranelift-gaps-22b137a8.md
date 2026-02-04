---
title: Update cranelift gaps
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.968205+01:00\""
closed-at: "2026-02-05T19:40:37.895509+01:00"
close-reason: Refreshed cranelift gap analysis with current parity focus
blocks:
  - hoist-update-feature-gaps-a080115c
---

Context: docs/cranelift_gap_analysis.md:1; cause: missing-opcode list outdated (bitcast/shuffle/call etc now implemented); fix: re-run opcode coverage audit and update counts; deps: hoist-fix-aarch64-call-6cb58430; verification: manual review
