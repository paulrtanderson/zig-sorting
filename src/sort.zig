const std = @import("std");
const mem = std.mem;

pub fn sort(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), T, T) bool,
) void {
    var scratch: [64]T = undefined;
    sortAux(T, items, context, lessThanFn, &scratch);
}

pub fn sortAux(
    comptime T: type,
    items: []T,
    context: anytype,
    comptime lessThanFn: fn (@TypeOf(context), T, T) bool,
    scratch: []T,
) void {
    const Context = struct {
        items: []T,
        scratch: []T,
        sub_ctx: @TypeOf(context),

        pub fn lessThan(ctx: @This(), i: usize, j: usize) bool {
            return lessThanFn(ctx.sub_ctx, ctx.items[i], ctx.items[j]);
        }

        pub fn swap(ctx: @This(), i: usize, j: usize) void {
            mem.swap(T, &ctx.items[i], &ctx.items[j]);
        }

        pub fn copyToScratch(ctx: @This(), src: usize, scratch_idx: usize) void {
            ctx.scratch[scratch_idx] = ctx.items[src];
        }

        pub fn copyFromScratch(ctx: @This(), scratch_idx: usize, dst: usize) void {
            ctx.items[dst] = ctx.scratch[scratch_idx];
        }
    };

    sortContext(0, items.len, Context{
        .items = items,
        .scratch = scratch,
        .sub_ctx = context,
    });
}

/// Context must provide: lessThan, swap, copyToScratch, copyFromScratch
pub fn sortContext(start: usize, end: usize, context: anytype) void {
    // Algorithm implementation
    _ = start;
    _ = end;
    _ = context;
}
