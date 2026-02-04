const std = @import("std");
const isle = @import("isle");

const prelude_path = "src/dsl/isle/ir_prelude.isle";
const base_preamble =
    \\const root = @import("../../root.zig");
    \\const Type = root.types.Type;
    \\const Value = root.entities.Value;
    \\const Inst = root.entities.Inst;
    \\const Block = root.entities.Block;
    \\const StackSlot = root.entities.StackSlot;
    \\const GlobalValue = root.entities.GlobalValue;
    \\const JumpTable = root.entities.JumpTable;
    \\const SigRef = root.entities.SigRef;
    \\const ExternalName = root.extfunc.ExternalName;
    \\const RelocDistance = root.extfunc.RelocDistance;
    \\const SymbolValueData = root.extfunc.SymbolValueData;
    \\const FuncRefData = root.extfunc.FuncRefData;
    \\const ValueSlice = root.lower.ValueSlice;
    \\const Imm64 = root.immediates.Imm64;
    \\const Ieee32 = root.immediates.Ieee32;
    \\const Ieee64 = root.immediates.Ieee64;
    \\const Offset32 = root.immediates.Offset32;
    \\const Immediate = root.immediates.Immediate;
    \\const MemFlags = root.memflags.MemFlags;
    \\const TrapCode = root.trapcode.TrapCode;
    \\const IntCC = root.condcodes.IntCC;
    \\const FloatCC = root.condcodes.FloatCC;
    \\const AtomicOrdering = root.atomics.AtomicOrdering;
    \\const AtomicRmwOp = root.atomics.AtomicRmwOp;
    \\const VecALUOp = root.aarch64_isle_types.VecALUOp;
    \\const VecElemSize = root.aarch64_isle_types.VecElemSize;
    \\const VecMisc2 = root.aarch64_isle_types.VecMisc2;
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var debug_comments = false;
    var input_path: []const u8 = undefined;
    var output_path: []const u8 = undefined;

    if (args.len == 3) {
        input_path = args[1];
        output_path = args[2];
    } else if (args.len == 4 and std.mem.eql(u8, args[1], "--debug-comments")) {
        debug_comments = true;
        input_path = args[2];
        output_path = args[3];
    } else {
        std.debug.print("Usage: {s} [--debug-comments] <input.isle> <output.zig>\n", .{args[0]});
        std.process.exit(1);
    }

    const prelude_content = std.fs.cwd().readFileAlloc(
        allocator,
        prelude_path,
        10 * 1024 * 1024, // 10MB max
    ) catch |err| {
        std.debug.print("Failed to read {s}: {}\n", .{ prelude_path, err });
        return err;
    };
    defer allocator.free(prelude_content);

    // Read input file
    const input_content = std.fs.cwd().readFileAlloc(
        allocator,
        input_path,
        10 * 1024 * 1024, // 10MB max
    ) catch |err| {
        std.debug.print("Failed to read {s}: {}\n", .{ input_path, err });
        return err;
    };
    defer allocator.free(input_content);

    const arch_preamble = if (std.mem.indexOf(u8, input_path, "aarch64") != null)
        \\const Aarch64Inst = root.aarch64_isle_types.Aarch64Inst;
        \\const Reg = root.aarch64_isle_types.Reg;
        \\const ImmLogic = root.aarch64_isle_types.ImmLogic;
        \\const CondCode = root.aarch64_isle_types.CondCode;
        \\const Cond = root.aarch64_isle_types.Cond;
        \\const VecALUModOp = root.aarch64_isle_types.VecALUModOp;
        \\const VecShiftImmOp = root.aarch64_isle_types.VecShiftImmOp;
        \\const VectorSize = root.aarch64_isle_types.VectorSize;
        \\const SveElemSize = root.aarch64_isle_types.SveElemSize;
        \\const ExtendOp = root.aarch64_isle_types.ExtendOp;
        \\const ShiftOp = root.aarch64_isle_types.ShiftOp;
        \\const SystemReg = root.aarch64_isle_types.SystemReg;
        \\const ShareabilityDomain = root.aarch64_isle_types.ShareabilityDomain;
        \\const ProducesFlags = root.aarch64_isle_types.ProducesFlags;
        \\const ConsumesFlags = root.aarch64_isle_types.ConsumesFlags;
        \\const ValueRegs = root.aarch64_isle_types.ValueRegs;
        \\const Context = root.aarch64_isle_impl.IsleContext;
        \\const externs_primary = root.aarch64_isle_impl;
        \\const externs_secondary = root.aarch64_isle_helpers;
        \\const recordRule = root.aarch64_isle_helpers.recordRule;
        \\
    else if (std.mem.indexOf(u8, input_path, "x64") != null)
        \\const X64Inst = root.x64_inst.Inst;
        \\const Context = root.lower.LowerCtx(root.x64_inst.Inst);
        \\const externs_primary = struct {};
        \\const externs_secondary = struct {};
        \\fn recordRule(_: []const u8) void {}
        \\
    else if (std.mem.indexOf(u8, input_path, "riscv64") != null)
        \\const Riscv64Inst = root.lower.ValueRegs;
        \\const Context = root.riscv64_isle_impl.IsleCtx;
        \\const externs_primary = root.riscv64_isle_impl;
        \\const externs_secondary = struct {};
        \\fn recordRule(_: []const u8) void {}
        \\
    else
        \\const Context = struct {};
        \\const externs_primary = struct {};
        \\const externs_secondary = struct {};
        \\fn recordRule(_: []const u8) void {}
        \\
    ;
    const preamble = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base_preamble, arch_preamble });
    defer allocator.free(preamble);

    // Compile ISLE to Zig
    var result = isle.compile(
        allocator,
        &.{
            isle.Source{
                .filename = prelude_path,
                .content = prelude_content,
            },
            isle.Source{
                .filename = input_path,
                .content = input_content,
            },
        },
        .{
            // Debug comments can explode code size. Default off, opt-in via CLI.
            .debug_comments = debug_comments,
            .preamble = preamble,
        },
    ) catch |err| {
        std.debug.print("ISLE compilation failed for {s}: {}\n", .{ input_path, err });
        return err;
    };
    defer result.deinit();

    // Write output file only if contents changed; avoids spurious rebuilds.
    var needs_write = true;
    if (std.fs.cwd().openFile(output_path, .{})) |f| {
        defer f.close();

        const st = try f.stat();
        if (st.size == result.code.len) {
            var buf: [8192]u8 = undefined;
            var off: usize = 0;
            while (off < result.code.len) {
                const n = try f.read(&buf);
                if (n == 0) break;
                if (!std.mem.eql(u8, result.code[off .. off + n], buf[0..n])) break;
                off += n;
            }
            if (off == result.code.len) needs_write = false;
        }
    } else |_| {
        // File missing or unreadable -> write it.
    }

    if (needs_write) {
        try std.fs.cwd().writeFile(.{
            .sub_path = output_path,
            .data = result.code,
        });
    }

    std.debug.print("Generated {s} from {s}\n", .{ output_path, input_path });
}
