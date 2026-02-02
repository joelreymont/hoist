---
title: Binding hashcons map
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T08:28:25.742059+01:00\\\"\""
closed-at: "2026-02-02T08:29:05.422543+01:00"
close-reason: completed
---

Context: src/dsl/isle/trie.zig:401; cause: RuleSet internBinding uses linear search over bindings; fix: add hash map with custom Binding hash/eql; why: avoid O(n) binding lookups in large rulesets
