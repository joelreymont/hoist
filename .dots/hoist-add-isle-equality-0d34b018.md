---
title: Add ISLE equality constraints
status: open
priority: 2
issue-type: task
created-at: "2026-01-16T15:05:22.740718+02:00"
---

Files: src/dsl/isle/trie.zig:706
What: Implement equality constraint selection in trie
Currently: TODO at line 706
Purpose: Handle patterns like (iadd x x) where same var appears twice
Verification: Test patterns with repeated variables
