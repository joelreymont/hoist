---
title: Retest vcode caps
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-18T00:01:32.811323+01:00\""
closed-at: "2026-02-18T00:04:39.143923+01:00"
close-reason: "discarded: unstable rerun; no sustained >=5% key-metric gains"
---

Full context: prior rejection of VCode capacity retention may be confounded by stale parent baseline drift (control run on unchanged code failed gate). Reapply VCode.resetForReuse + AArch64Lowered.resetForReuse reuse path and compare against fresh no-change baseline /tmp/hoist-control-current.log captured in-session. Retain only if >=5% gains with no regressions, then rerun stability.
