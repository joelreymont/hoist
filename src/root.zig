pub const context = @import("context.zig");

pub const bforest = @import("foundation/bforest.zig");
pub const bitset = @import("foundation/bitset.zig");
pub const entity = @import("foundation/entity.zig");
pub const maps = @import("foundation/maps.zig");

pub const types = @import("ir/types.zig");
pub const entities = @import("ir/entities.zig");
pub const opcodes = @import("ir/opcodes.zig");
pub const instructions = @import("ir/instructions.zig");
pub const instruction_format = @import("ir/instruction_format.zig");
pub const trapcode = @import("ir/trapcode.zig");
pub const condcodes = @import("ir/condcodes.zig");
pub const immediates = @import("ir/immediates.zig");
pub const memflags = @import("ir/memflags.zig");
pub const value_list = @import("ir/value_list.zig");
pub const block_call = @import("ir/block_call.zig");
pub const atomic = @import("ir/atomic.zig");
pub const atomics = @import("ir/atomics.zig");
pub const signature = @import("ir/signature.zig");
pub const constant = @import("ir/constant.zig");
pub const constants = @import("ir/constants.zig");
pub const extfunc = @import("ir/extfunc.zig");
pub const dfg = @import("ir/dfg.zig");
pub const layout = @import("ir/layout.zig");
pub const instruction_data = @import("ir/instruction_data.zig");
pub const stack_slot_data = @import("ir/stack_slot_data.zig");
pub const stackslots = @import("ir/stackslots.zig");
pub const stackmaps = @import("ir/stackmaps.zig");
pub const global_value_data = @import("ir/global_value_data.zig");
pub const jump_table_data = @import("ir/jump_table_data.zig");
pub const flowgraph = @import("ir/flowgraph.zig");
pub const function = @import("ir/function.zig");
pub const builder = @import("ir/builder.zig");
pub const optimize = @import("ir/optimize.zig");
pub const domtree = @import("ir/domtree.zig");
pub const loops = @import("ir/loops.zig");
pub const verifier = @import("ir/verifier.zig");
pub const cfg = @import("ir/cfg.zig");
pub const sourceloc = @import("ir/sourceloc.zig");
pub const debuginfo = @import("ir/debuginfo.zig");

// SSA tests
test {
    _ = @import("ir/ssa_tests.zig");
}

pub const isle_sema = @import("dsl/isle/sema.zig");
pub const isle_trie = @import("dsl/isle/trie.zig");
pub const isle_codegen = @import("dsl/isle/codegen.zig");
pub const isle_compile = @import("dsl/isle/compile.zig");
pub const isle_runtime = @import("dsl/isle/runtime.zig");

pub const dsl = struct {
    pub const isle = struct {
        pub const sema = isle_sema;
        pub const trie = isle_trie;
        pub const codegen = struct {
            pub const match = @import("dsl/isle/codegen/match.zig");
            pub const constructors = @import("dsl/isle/codegen/constructors.zig");
            pub const extractors = @import("dsl/isle/codegen/extractors.zig");
        };
        pub const compile = isle_compile;
        pub const runtime = isle_runtime;
    };
};
pub const reg = @import("machinst/reg.zig");
pub const machinst = @import("machinst/machinst.zig");
pub const buffer = @import("machinst/buffer.zig");
pub const vcode = @import("machinst/vcode.zig");
pub const abi = @import("machinst/abi.zig");
pub const regalloc = @import("machinst/regalloc.zig");
pub const regalloc2_types = @import("machinst/regalloc2/types.zig");
pub const regalloc2_api = @import("machinst/regalloc2/api.zig");
pub const regalloc2_moves = @import("machinst/regalloc2/moves.zig");
pub const regalloc2_liveness = @import("machinst/regalloc2/liveness.zig");
pub const regalloc2_datastructures = @import("machinst/regalloc2/datastructures.zig");
pub const lower = @import("machinst/lower.zig");
pub const backend = @import("machinst/backend.zig");
pub const compile = @import("machinst/compile.zig");

// Machinst tests
test {
    _ = @import("machinst/backend.zig");
}

// Codegen pipeline
pub const codegen_compile = @import("codegen/compile.zig");
pub const codegen_context = @import("codegen/context.zig");
pub const codegen_optimize = @import("codegen/optimize.zig");
pub const legalize_types = @import("codegen/legalize_types.zig");
pub const legalize_ops = @import("codegen/legalize_ops.zig");
pub const lower_helpers = @import("codegen/lower_helpers.zig");
pub const isle_ctx = @import("codegen/isle_ctx.zig");

pub const codegen = struct {
    pub const compile = codegen_compile;
    pub const context = codegen_context;
    pub const optimize = codegen_optimize;
    pub const lower_helpers = @import("codegen/lower_helpers.zig");
    pub const isle_ctx = @import("codegen/isle_ctx.zig");
};

pub const ir_ns = struct {
    pub const types = @import("ir/types.zig");
    pub const entities = @import("ir/entities.zig");
};

// Codegen tests
test {
    _ = @import("codegen/compile.zig");
    _ = @import("codegen/context.zig");
    _ = @import("codegen/optimize.zig");
    _ = @import("codegen/legalize_types.zig");
    _ = @import("codegen/legalize_ops.zig");
    _ = @import("codegen/lower_helpers.zig");
    _ = @import("codegen/isle_ctx.zig");
}

// Backend tests
test {
    _ = @import("backends/aarch64/legalize.zig");
    _ = @import("backends/aarch64/frame_layout_test.zig");
}

pub const x64_inst = @import("backends/x64/inst.zig");
pub const x64_emit = @import("backends/x64/emit.zig");
pub const x64_abi = @import("backends/x64/abi.zig");
pub const x64_lower = @import("backends/x64/lower.zig");
pub const x64_isa = @import("backends/x64/isa.zig");

pub const aarch64_inst = @import("backends/aarch64/inst.zig");
pub const aarch64_emit = @import("backends/aarch64/emit.zig");
pub const aarch64_abi = @import("backends/aarch64/abi.zig");
pub const aarch64_lower = @import("backends/aarch64/lower.zig");
pub const aarch64_isle_helpers = @import("backends/aarch64/isle_helpers.zig");
pub const aarch64_isle_impl = @import("backends/aarch64/isle_impl.zig");
pub const aarch64_isa = @import("backends/aarch64/isa.zig");
pub const aarch64_legalize = @import("backends/aarch64/legalize.zig");

pub const backends = struct {
    pub const aarch64 = struct {
        pub const inst = aarch64_inst;
        pub const emit = aarch64_emit;
        pub const abi = aarch64_abi;
        pub const lower = aarch64_lower;
        pub const isle_helpers = aarch64_isle_helpers;
        pub const isle_impl = aarch64_isle_impl;
        pub const isa = aarch64_isa;
        pub const legalize = aarch64_legalize;
    };
};

pub const ir = @import("ir/function.zig");
