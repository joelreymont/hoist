# E-graph Optimization Design

Research notes for implementing e-graph-based optimizations in Hoist.

## Literature Review

### egg: Fast and Extensible Equality Saturation (POPL 2021)

**Paper**: [egg: Fast and Extensible Equality Saturation](https://doi.org/10.1145/3434304) by Max Willsey et al.
- Won Distinguished Paper at POPL 2021
- [SIGPLAN Blog Overview](https://blog.sigplan.org/2021/04/06/equality-saturation-with-egg/)
- [Full thesis](https://www.mwillsey.com/thesis/thesis.pdf)

**Key Contributions**:

1. **Rebuilding**: Amortized invariant restoration technique providing asymptotic speedups
   - Takes advantage of equality saturation's distinct workload
   - Specialized for equality saturation vs general e-graph maintenance

2. **E-class Analyses**: General mechanism integrating domain-specific analyses into e-graphs
   - Reduces ad hoc manipulation
   - Enables state-of-the-art results across diverse domains

**Implementation**: [egg library](https://github.com/egraphs-good/egg) (Rust)

### Cranelift's Approach: ISLE + E-graphs

**References**:
- [Cranelift E-graph RFC](https://github.com/bytecodealliance/rfcs/blob/main/accepted/cranelift-egraph.md)
- [RFC PR #27](https://github.com/bytecodealliance/rfcs/pull/27)
- [ISLE Blog Post](https://cfallin.org/blog/2023/01/20/cranelift-isle/)
- [Cranelift 2022 Progress](https://bytecodealliance.org/articles/cranelift-progress-2022)

**Design Philosophy**:
- First production compiler to use e-graphs for unified optimization
- Reuses ISLE (Instruction Selection/Lowering Expressions DSL) for both:
  - Instruction lowering patterns (per-architecture)
  - Machine-independent optimizing rewrites
- Avoids proliferation of multiple rewrite systems

**Integration**:
- ISLE-based rewrite rules operate on an e-graph
- Cost-based extraction picks best option per node after rewrites
- Extended ISLE to support "multiplicity":
  - Multiple rules can match
  - Matchers on e-class IDs see all available e-nodes per e-class
  - Extractors bind e-classes, not just e-nodes

**Timeline**:
- 2022: E-graph optimization passes added to mid-end
- 2023: E-graph optimizations enabled by default

## E-graph Data Structure Fundamentals

Based on [e-graph primer](https://www.cole-k.com/2023/07/24/e-graphs-primer/) and [Wikipedia](https://en.wikipedia.org/wiki/E-graph):

### Core Concepts

**E-graph**: Data structure storing congruence relation over terms
- Compactly represents large sets of structurally similar expressions
- Small e-graphs can represent exponentially many expressions

**E-class**: Equivalence class of equivalent expressions
- Dotted boxes in diagrams
- Contains equivalent e-nodes
- Identified by opaque IDs (comparable for equality)
- Two e-nodes are equivalent iff they're in same e-class

**E-node**: Function application to e-class IDs
- Solid boxes in diagrams
- Operator with e-class children (NOT other e-nodes)
- Key distinction from AST: children are e-classes, not e-nodes
- Arrows point from parent e-node to child e-class

### Implementation Details

**Union-Find**: Efficiently maintain and merge equivalence classes
- Core data structure for e-class management
- Used by SMT solvers (Z3, CVC4)

**Representation Property**: E-graph represents term if any e-class does; e-class represents term if any e-node does

### Applications

- Automated theorem proving (SMT solvers)
- Program optimization (equality saturation)
- Superoptimization

## Design Choices for Hoist

### Option 1: ISLE-Based (Cranelift Model)

**Advantages**:
- Reuse existing ISLE infrastructure (src/backends/*/lower.isle)
- Single DSL for lowering + optimization
- Production-proven (Cranelift default since 2023)
- Natural fit: already pattern-matching on IR

**Challenges**:
- ISLE currently designed for single-match lowering
- Need multiplicity support (e-class → multiple e-nodes)
- Need e-class analysis integration
- Significant ISLE extension required

### Option 2: Standalone E-graph (egg Model)

**Advantages**:
- Clean separation: optimization vs lowering
- Leverage egg's research (rebuilding, e-class analyses)
- Well-studied performance characteristics
- Easier to reason about correctness

**Challenges**:
- Duplicate pattern language (ISLE for lowering, Rust for rewrites)
- Bidirectional IR ↔ e-graph conversion overhead
- More complex integration into pipeline

### Option 3: Hybrid

**Advantages**:
- E-graph for mid-end optimizations (IR → IR)
- ISLE for backend lowering (IR → MachInst)
- Each tool used for its strength

**Challenges**:
- Two systems to maintain
- Need clear phase boundaries

## Recommended Approach

**Start with Option 2 (Standalone E-graph)** for these reasons:

1. **Separation of concerns**: Optimization (mid-end) vs lowering (backend)
2. **Research leverage**: egg's rebuilding and e-class analyses are proven
3. **Incremental adoption**: Add e-graph pass to existing pipeline without touching ISLE
4. **Correctness focus**: Easier to verify optimization correctness in isolation
5. **Performance data**: Measure overhead before committing to ISLE integration

**Migration path**:
- Phase 1: Standalone e-graph optimizer (docs/egraph-design.md)
- Phase 2: Measure performance vs ISLE-based approach
- Phase 3: If ISLE integration justified, extend ISLE with multiplicity

## Implementation Plan

See remaining dots for specific tasks:
- Survey e-graph literature (this document)
- Design EGraph data structures (src/codegen/opts/egraph/)
- Implement e-graph builder (IR → e-graph)
- Add algebraic rewrite rules
- Implement equality saturation
- Extract optimized IR from e-graph
- Integrate into optimize pipeline
- Test e-graph optimizations

## References

### Papers
- [egg: Fast and Extensible Equality Saturation (POPL 2021)](https://doi.org/10.1145/3434304)
- [Max Willsey's Thesis](https://www.mwillsey.com/thesis/thesis.pdf)
- [Combining E-Graphs with Abstract Interpretation](https://arxiv.org/pdf/2205.14989)
- [VeriISLE: Verifying Instruction Selection](http://reports-archive.adm.cs.cmu.edu/anon/2023/CMU-CS-23-126.pdf)

### Implementations
- [egg library (Rust)](https://github.com/egraphs-good/egg)
- [Cranelift ISLE](https://github.com/bytecodealliance/wasmtime/blob/main/cranelift/isle/docs/language-reference.md)

### Tutorials
- [E-graphs Primer](https://www.cole-k.com/2023/07/24/e-graphs-primer/)
- [What's in an e-graph?](https://bernsteinbear.com/blog/whats-in-an-egraph/)
- [E-graphs and Equality Saturation (Metatheory.jl)](https://juliasymbolics.github.io/Metatheory.jl/dev/egraphs/)
- [CS 6120: Technology Mapping with Egraphs](https://www.cs.cornell.edu/courses/cs6120/2025sp/blog/superopt/)
