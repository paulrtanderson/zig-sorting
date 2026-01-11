const std = @import("std");
const sort = std.sort;

const pdq = sort.pdq;
const pdqContext = sort.pdqContext;

pub fn printTesting(writer: *std.Io.Writer) !void {
    try writer.write("Testing pdq sort.\n");
}


test "pdq sort test" {
    var array: [10]u32 = .{9, 7, 5, 3, 1, 0, 2, 4, 6, 8};
    var ctx: pdqContext(u32) = pdqContext(u32){};
    pdq.sort(&ctx, &array);
    try std.testing.expect(array == .{0,1,2,3,4,5,6,7,8,9});
}