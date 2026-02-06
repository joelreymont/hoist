---
title: Fix dot-finish bookmark push
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T19:57:00.162436+01:00\""
closed-at: "2026-02-06T19:57:29.157384+01:00"
close-reason: Always set/push codex/indirect-return bookmark
---

Context: /Users/joel/Work/hoist/tools/dot-finish; cause: helper used default push path and skipped bookmark update; fix: always set and push codex/indirect-return; deps: hoist-add-dot-finish-85fa5447; verification: run tools/dot-finish --help and dry run by closing a dot
