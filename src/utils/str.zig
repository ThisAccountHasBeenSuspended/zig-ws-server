/// Checks if a `data` exists in `self`.
///
/// Computes in **O(n²)** time.
pub fn contains(self: []const u8, data: []const u8) bool {
    outer: for (0..self.len) |xidx| {
        if (self.len < (xidx + data.len)) {
            break :outer;
        }

        for (data, 0..) |byte, yidx| {
            if (self[xidx + yidx] != byte) {
                continue :outer;
            }
        }

        return true;
    }
    return false;
}
