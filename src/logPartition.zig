const Partition = struct {
    pub const T = usize;
    pub const CmpFn = fn (a: [*]const T, b: [*]const T) bool;

    fn logBlockRead(a: [*]T, piv: *const T, wLen: u6, cmp: CmpFn) usize {
        var r: usize = 0;
        var ptr = a;
        for (0..wLen) |i| {
            const bit: usize = @intFromBool(cmp(ptr, piv));
            r |= bit << @intCast(i);
            ptr += 1;
        }
        return r;
    }
};
