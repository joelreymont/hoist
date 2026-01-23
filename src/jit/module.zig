const std = @import("std");
const Allocator = std.mem.Allocator;

const root = @import("../root.zig");
const types = @import("../ir/types.zig");
const sig_mod = @import("../ir/signature.zig");
const module = @import("../module/module.zig");
const symbols = @import("../module/symbols.zig");
const jit_mem = @import("memory.zig");

const FuncId = module.FuncId;
const DataId = module.DataId;
const Linkage = module.Linkage;
const ModuleDeclarations = module.ModuleDeclarations;
const DataDesc = module.DataDesc;

/// JIT-compiled blob with relocations.
const CompiledBlob = struct {
    ptr: [*]u8,
    size: usize,
    relocs: std.ArrayList(Reloc),

    fn init(alloc: Allocator) CompiledBlob {
        return .{
            .ptr = undefined,
            .size = 0,
            .relocs = std.ArrayList(Reloc).init(alloc),
        };
    }

    fn deinit(self: *CompiledBlob) void {
        self.relocs.deinit();
    }

    fn performRelocs(self: *const CompiledBlob, ctx: anytype) void {
        for (self.relocs.items) |reloc| {
            const at = self.ptr + reloc.offset;
            const base = ctx.getAddr(reloc.target);
            const what = base + @as(usize, @intCast(reloc.addend));

            switch (reloc.kind) {
                .abs8 => {
                    const ptr: *u64 = @ptrCast(@alignCast(at));
                    ptr.* = @intCast(what);
                },
                .arm64_call => {
                    const iptr: *u32 = @ptrCast(@alignCast(at));
                    const diff = @as(isize, @intCast(what)) - @as(isize, @intCast(@intFromPtr(at)));
                    const offset = @as(i32, @intCast(diff >> 2));
                    std.debug.assert((offset >> 26 == -1) or (offset >> 26 == 0));
                    const imm26 = @as(u32, @bitCast(offset)) & 0x3ffffff;
                    iptr.* |= imm26;
                },
                .aarch64_adr_prel_pg_hi21 => {
                    const get_page = struct {
                        fn f(x: usize) usize {
                            return x & ~@as(usize, 0xfff);
                        }
                    }.f;
                    const pcrel = @as(i32, @intCast(get_page(what) - get_page(@intFromPtr(at))));
                    const iptr: *u32 = @ptrCast(@alignCast(at));
                    const hi21 = @as(u32, @bitCast(pcrel >> 12));
                    const lo = (hi21 & 0x3) << 29;
                    const hi = (hi21 & 0x1ffffc) << 3;
                    iptr.* |= lo | hi;
                },
                .aarch64_add_abs_lo12_nc => {
                    const iptr: *u32 = @ptrCast(@alignCast(at));
                    const imm12 = @as(u32, @intCast(what & 0xfff)) << 10;
                    iptr.* |= imm12;
                },
            }
        }
    }
};

/// Relocation kind.
const RelocKind = enum {
    abs8,
    arm64_call,
    aarch64_adr_prel_pg_hi21,
    aarch64_add_abs_lo12_nc,
};

/// Module relocation.
const Reloc = struct {
    kind: RelocKind,
    offset: u32,
    target: RelocTarget,
    addend: i64,
};

/// Relocation target.
const RelocTarget = union(enum) {
    func: FuncId,
    data: DataId,
    symbol: []const u8,
};

/// JIT module.
pub const JitModule = struct {
    alloc: Allocator,
    mem: *jit_mem.Mem,
    decls: ModuleDeclarations,
    funcs: std.ArrayList(?CompiledBlob),
    data: std.ArrayList(?CompiledBlob),
    syms: std.StringHashMap(usize),
    to_finalize: std.ArrayList(FuncId),
    data_to_finalize: std.ArrayList(DataId),

    pub fn init(alloc: Allocator) !JitModule {
        const mem = try alloc.create(jit_mem.Mem);
        errdefer alloc.destroy(mem);
        mem.* = try jit_mem.Mem.init(alloc, 1024 * 1024);

        return .{
            .alloc = alloc,
            .mem = mem,
            .decls = ModuleDeclarations.init(alloc),
            .funcs = std.ArrayList(?CompiledBlob).init(alloc),
            .data = std.ArrayList(?CompiledBlob).init(alloc),
            .syms = std.StringHashMap(usize).init(alloc),
            .to_finalize = std.ArrayList(FuncId).init(alloc),
            .data_to_finalize = std.ArrayList(DataId).init(alloc),
        };
    }

    pub fn deinit(self: *JitModule) void {
        for (self.funcs.items) |*maybe_blob| {
            if (maybe_blob.*) |*blob| {
                blob.deinit();
            }
        }
        for (self.data.items) |*maybe_blob| {
            if (maybe_blob.*) |*blob| {
                blob.deinit();
            }
        }
        self.funcs.deinit();
        self.data.deinit();
        self.syms.deinit();
        self.to_finalize.deinit();
        self.data_to_finalize.deinit();
        self.decls.deinit();
        self.mem.deinit();
        self.alloc.destroy(self.mem);
    }

    pub fn declareFunction(
        self: *JitModule,
        name: []const u8,
        linkage: Linkage,
        signature: sig_mod.Signature,
    ) !FuncId {
        _ = signature;
        const name_copy = try self.alloc.dupe(u8, name);
        const id = FuncId.from(@intCast(self.funcs.items.len));
        try self.funcs.append(null);
        try self.decls.names.put(name_copy, .{ .func = id });
        _ = linkage;
        return id;
    }

    pub fn declareData(
        self: *JitModule,
        name: []const u8,
        linkage: Linkage,
        writable: bool,
        tls: bool,
    ) !DataId {
        _ = linkage;
        _ = writable;
        _ = tls;
        const name_copy = try self.alloc.dupe(u8, name);
        const id = DataId.from(@intCast(self.data.items.len));
        try self.data.append(null);
        try self.decls.names.put(name_copy, .{ .data = id });
        return id;
    }

    pub fn defineFunction(
        self: *JitModule,
        id: FuncId,
        bytes: []const u8,
        relocs: []const Reloc,
    ) !void {
        var blob = CompiledBlob.init(self.alloc);
        blob.size = bytes.len;
        try blob.relocs.appendSlice(relocs);

        // Allocate and copy
        blob.ptr = self.mem.ptr + self.mem.len; // TODO: track allocation
        @memcpy(blob.ptr[0..bytes.len], bytes);

        self.funcs.items[id.idx] = blob;
        try self.to_finalize.append(id);
    }

    pub fn defineData(
        self: *JitModule,
        id: DataId,
        desc: *const DataDesc,
    ) !void {
        var blob = CompiledBlob.init(self.alloc);
        const bytes = switch (desc.init) {
            .uninit => @panic("uninit data"),
            .zeros => |sz| blk: {
                blob.size = sz;
                blob.ptr = self.mem.ptr + self.mem.len;
                @memset(blob.ptr[0..sz], 0);
                break :blk blob.ptr[0..sz];
            },
            .bytes => |b| blk: {
                blob.size = b.len;
                blob.ptr = self.mem.ptr + self.mem.len;
                @memcpy(blob.ptr[0..b.len], b);
                break :blk blob.ptr[0..b.len];
            },
        };
        _ = bytes;

        for (desc.func_relocs.items) |fr| {
            try blob.relocs.append(.{
                .kind = .abs8,
                .offset = fr.offset,
                .target = .{ .func = fr.func },
                .addend = 0,
            });
        }
        for (desc.data_relocs.items) |dr| {
            try blob.relocs.append(.{
                .kind = .abs8,
                .offset = dr.offset,
                .target = switch (dr.target) {
                    .func => |f| .{ .func = f },
                    .data => |d| .{ .data = d },
                    .symbol => |s| .{ .symbol = s },
                },
                .addend = dr.addend,
            });
        }

        self.data.items[id.idx] = blob;
        try self.data_to_finalize.append(id);
    }

    pub fn finalize(self: *JitModule) !void {
        const getAddr = struct {
            fn f(s: *JitModule, target: RelocTarget) usize {
                return switch (target) {
                    .func => |fid| blk: {
                        const b = s.funcs.items[fid.idx] orelse unreachable;
                        break :blk @intFromPtr(b.ptr);
                    },
                    .data => |did| blk: {
                        const b = s.data.items[did.idx] orelse unreachable;
                        break :blk @intFromPtr(b.ptr);
                    },
                    .symbol => |sym| s.syms.get(sym) orelse unreachable,
                };
            }
        }.f;

        for (self.to_finalize.items) |id| {
            if (self.funcs.items[id.idx]) |*blob| {
                blob.performRelocs(getAddr);
            }
        }
        self.to_finalize.clearRetainingCapacity();

        for (self.data_to_finalize.items) |id| {
            if (self.data.items[id.idx]) |*blob| {
                blob.performRelocs(getAddr);
            }
        }
        self.data_to_finalize.clearRetainingCapacity();
    }

    pub fn getFn(self: *const JitModule, id: FuncId, comptime T: type) T {
        const blob = self.funcs.items[id.idx] orelse unreachable;
        return @ptrCast(@alignCast(blob.ptr));
    }

    pub fn getData(self: *const JitModule, id: DataId, comptime T: type) T {
        const blob = self.data.items[id.idx] orelse unreachable;
        return @ptrCast(@alignCast(blob.ptr));
    }

    pub fn declarations(self: *const JitModule) *const ModuleDeclarations {
        return &self.decls;
    }
};
