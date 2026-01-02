//! IR module - re-exports all IR components.

pub const Function = @import("ir/function.zig").Function;
pub const Block = @import("ir/entities.zig").Block;
pub const Inst = @import("ir/entities.zig").Inst;
pub const Value = @import("ir/entities.zig").Value;
pub const Type = @import("ir/types.zig").Type;
pub const I32 = Type.I32;
pub const I64 = Type.I64;
pub const Signature = @import("ir/signature.zig").Signature;
pub const Verifier = @import("ir/verifier.zig").Verifier;
pub const FunctionBuilder = @import("ir/builder.zig").FunctionBuilder;
pub const ControlFlowGraph = @import("ir/cfg.zig").ControlFlowGraph;
pub const DominatorTree = @import("ir/domtree.zig").DominatorTree;
pub const LoopAnalysis = @import("ir/loops.zig").LoopAnalysis;
