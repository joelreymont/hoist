pub fn len(self: Self) usize {
    var count: usize = 0;
    for (self.elems) |e| {
        count += e.len();
    }
    return count;
}
