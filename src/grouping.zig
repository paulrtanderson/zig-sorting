const std = @import("std");

/// Elements < pivot are "zeros", elements >= pivot are "ones".
pub fn GroupResult(comptime T: type) type {
    return struct {
        /// Pointer to where leftover "zeros" begin (end of complete blocks) TODO: can we just calculate this from leftover counts?
        leftovers_start: [*]T,
        /// Number of complete blocks containing "zeros" (elements < pivot)
        left_blocks: usize,
        /// Number of complete blocks containing "ones" (elements >= pivot)
        right_blocks: usize,
        /// Number of leftover "zeros" that didn't form a complete block
        leftover_zeros: usize,
        /// Number of leftover "ones" that didn't form a complete block
        leftover_ones: usize,
    };
}

/// Groups elements into blocks of size `buffer.len`.
/// After grouping, the array contains complete blocks of "zeros" and "ones",
/// followed by leftover elements.
pub fn groupIntoBlocks(
    comptime T: type,
    array: []T,
    buffer: []T,
    pivot: T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), T, T) bool,
) GroupResult(T) {
    const block_len = buffer.len;
    std.debug.assert(block_len > 0);

    if (array.len <= block_len) {
        // Array too small for blocking - just partition into buffer
        return groupSmall(T, array, buffer, pivot, context, lessThan);
    }

    var next_zero_position: usize = 0; // write index for "zeros" (in main array)
    var next_one_position_in_buffer: usize = 0; // write index for "ones" (in buffer)
    var right_blocks: usize = 0;

    for (0..array.len) |i| {
        const elem = array[i];
        const is_zero = lessThan(context, elem, pivot);
        if (is_zero) {
            array[next_zero_position] = elem;
            next_zero_position += 1;
        } else {
            buffer[next_one_position_in_buffer] = elem;
            next_one_position_in_buffer += 1;
        }

        // When buffer is full, we have a complete "ones" block that we need to insert back into the array
        if (next_one_position_in_buffer == block_len) {

            // we likely have an incomplete "zeros" fragment at the end we need to shift this right so we can insert the complete block of "ones"
            const fragment_size = next_zero_position % block_len;
            const insert_pos = next_zero_position - fragment_size;
            if (fragment_size > 0) {
                const dest = array[insert_pos + block_len .. insert_pos + block_len + fragment_size];
                const source = array[insert_pos .. insert_pos + fragment_size];
                @memcpy(dest, source);
            }

            // Copy the "ones" block from buffer into the array
            @memcpy(array[insert_pos .. insert_pos + block_len], buffer[0..block_len]);

            next_zero_position += block_len;
            next_one_position_in_buffer = 0;
            right_blocks += 1;
        }
    }

    // The leftover "ones" in the buffer are simply copied after the "zeros" in the array
    @memcpy(array[next_zero_position .. next_zero_position + next_one_position_in_buffer], buffer[0..next_one_position_in_buffer]);

    const leftover_zeros = next_zero_position % block_len;
    const left_blocks = (array.len - next_one_position_in_buffer) / block_len - right_blocks;

    return .{
        .leftovers_start = array.ptr + (left_blocks + right_blocks) * block_len,
        .left_blocks = left_blocks,
        .right_blocks = right_blocks,
        .leftover_zeros = leftover_zeros,
        .leftover_ones = next_one_position_in_buffer,
    };
}

/// Handle small arrays that don't need blocking
fn groupSmall(
    comptime T: type,
    array: []T,
    buffer: []T,
    pivot: T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), T, T) bool,
) GroupResult(T) {
    var l: usize = 0;
    var r: usize = 0;

    for (array) |elem| {
        if (lessThan(context, elem, pivot)) {
            array[l] = elem;
            l += 1;
        } else {
            buffer[r] = elem;
            r += 1;
        }
    }

    // Copy ones after zeros
    @memcpy(array[l .. l + r], buffer[0..r]);

    return .{
        .leftovers_start = array.ptr,
        .left_blocks = 0,
        .right_blocks = 0,
        .leftover_zeros = l,
        .leftover_ones = r,
    };
}

// ============ Tests ============

const testing = std.testing;

fn checkBlocked(
    comptime T: type,
    array: []T,
    block_size: usize,
    pivot: T,
    context: anytype,
    comptime lessThan: fn (context: @TypeOf(context), T, T) bool,
) !GroupResult(T) {
    var i: usize = 0;
    var left_blocks: usize = 0;
    var right_blocks: usize = 0;
    const len = array.len;

    // Check complete blocks (must be homogeneous)
    blk: while (i + block_size <= len) : (i += block_size) {
        const first = array[i];
        const is_zero_block = lessThan(context, first, pivot);

        for (0..block_size) |j| {
            const elem = array[i + j];
            const is_zero = lessThan(context, elem, pivot);
            if (is_zero != is_zero_block) {
                break :blk;
            }
        }
        if (is_zero_block) {
            left_blocks += 1;
        } else {
            right_blocks += 1;
        }
    }

    const blocks_end = i;

    // Check fragments: all zeros must come before all ones
    var seen_one = false;
    var leftover_zeros: usize = 0;
    var leftover_ones: usize = 0;

    while (i < len) : (i += 1) {
        const elem = array[i];
        const is_zero = lessThan(context, elem, pivot);

        if (is_zero) {
            testing.expect(!seen_one) catch |err| {
                std.debug.print("Fragment error: zero found after one at index {d}\n", .{i});
                return err;
            };
            leftover_zeros += 1;
        } else {
            seen_one = true;
            leftover_ones += 1;
        }
    }

    testing.expect(leftover_zeros < block_size) catch |err| {
        std.debug.print("Fragment error: {d} leftover zeros exceeds block_size {d}\n", .{ leftover_zeros, block_size });
        return err;
    };
    testing.expect(leftover_ones < block_size) catch |err| {
        std.debug.print("Fragment error: {d} leftover ones exceeds block_size {d}\n", .{ leftover_ones, block_size });
        return err;
    };
    return .{
        .leftovers_start = array.ptr + blocks_end,
        .left_blocks = left_blocks,
        .right_blocks = right_blocks,
        .leftover_zeros = leftover_zeros,
        .leftover_ones = leftover_ones,
    };
}

pub fn Tagged(comptime T: type) type {
    return struct {
        value: T,
        original_index: usize,
    };
}

fn checkBlockedIsStable(comptime T: type, result: []Tagged(T), pivot: T, context: anytype, lessThan: fn (context: @TypeOf(context), T, T) bool) !void {
    var last_zero_idx: isize = -1;
    var last_one_idx: isize = -1;

    for (result) |item| {
        if (lessThan(context, item.value, pivot)) {
            if (item.original_index <= last_zero_idx) return error.UnstableZero;
            last_zero_idx = @intCast(item.original_index);
        } else {
            if (item.original_index <= last_one_idx) return error.UnstableOne;
            last_one_idx = @intCast(item.original_index);
        }
    }
}

fn taggedLessThan(comptime T: type, comptime lessThan: fn (context: void, T, T) bool) fn (context: void, Tagged(T), Tagged(T)) bool {
    return struct {
        fn lessThanTagged(context: void, a: Tagged(T), b: Tagged(T)) bool {
            return lessThan(context, a.value, b.value);
        }
    }.lessThanTagged;
}

fn checkGroupingBlocked(
    comptime T: type,
    comptime size: usize,
    input: [size]T,
    pivot: T,
    comptime lessThan: fn (void, T, T) bool,
) !void {
    var array = input;
    const buffer_size = 5;
    var buffer: [buffer_size]T = undefined;

    const result = groupIntoBlocks(T, &array, &buffer, pivot, {}, lessThan);
    const expected_metadata = try checkBlocked(T, &array, buffer_size, pivot, {}, lessThan);

    try testing.expectEqual(expected_metadata, result);
}

fn checkGroupingStable(
    comptime T: type,
    comptime size: usize,
    input: [size]T,
    pivot: T,
    comptime lessThan: fn (void, T, T) bool,
) !void {
    var tagged_array: [size]Tagged(T) = undefined;
    for (input, 0..) |val, i| {
        tagged_array[i] = .{ .value = val, .original_index = i };
    }

    const buffer_size = 5;
    var buffer: [buffer_size]Tagged(T) = undefined;

    const tagged_pivot = Tagged(T){ .value = pivot, .original_index = undefined };
    const lessThanTagged = taggedLessThan(T, lessThan);

    _ = groupIntoBlocks(Tagged(T), &tagged_array, &buffer, tagged_pivot, {}, lessThanTagged);

    try checkBlockedIsStable(T, &tagged_array, pivot, {}, lessThan);
}

test "group i32s into blocks" {
    const size = 20;
    const input: [size]i32 = .{ 3, 7, 2, 8, 5, 1, 6, 4, 9, 0, 12, 15, 11, 14, 10, 13, 18, 17, 19, 16 };
    const lessThanFn = std.sort.asc(i32);
    const pivot: i32 = 10;
    try checkGroupingBlocked(i32, size, input, pivot, lessThanFn);
    try checkGroupingStable(i32, size, input, pivot, lessThanFn);
}

test "group i32s with all ones" {
    const size = 6;
    const input: [size]i32 = .{ 5, 6, 7, 8, 9, 10 };
    const lessThanFn = std.sort.asc(i32);
    const pivot: i32 = 1; // all elements >= pivot
    try checkGroupingBlocked(i32, size, input, pivot, lessThanFn);
    try checkGroupingStable(i32, size, input, pivot, lessThanFn);
}

test "group i32s with all zeros" {
    const size = 6;
    const input: [size]i32 = .{ -10, -9, -8, -7, -6, -5 };
    const lessThanFn = std.sort.asc(i32);
    const pivot: i32 = 0; // all elements < pivot
    try checkGroupingBlocked(i32, size, input, pivot, lessThanFn);
    try checkGroupingStable(i32, size, input, pivot, lessThanFn);
}

test "group strings into blocks" {
    const size = 12;
    const input: [size][]const u8 = .{ "delta", "alpha", "charlie", "bravo", "alpha", "echo", "juliet", "foxtrot", "golf", "hotel", "india", "juliet" };
    const stringLessThan = struct {
        fn stringLessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.order(u8, lhs, rhs) == .lt;
        }
    }.stringLessThan;
    const pivot: []const u8 = "foxtrot";
    try checkGroupingBlocked([]const u8, size, input, pivot, stringLessThan);
    try checkGroupingStable([]const u8, size, input, pivot, stringLessThan);
}
