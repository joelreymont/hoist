---
title: Add decision tree to ISLE trie.zig
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-26T11:10:04.463385+01:00\""
closed-at: "2026-01-26T11:27:24.867851+01:00"
---

File: src/dsl/isle/trie.zig
Add decision tree representation for pattern matching:
- pub const Decision = union(enum) { match, bind, call, fail }
- pub const DecisionTree = struct { root: []Decision }
- Build from RuleSet during compilation
Verify: zig build test -Dtest-filter=trie
