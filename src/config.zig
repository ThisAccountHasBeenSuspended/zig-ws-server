const std = @import("std");

pub const PerMessageDeflate = struct {
    /// Set this value to true to compress data before sending.
    enabled: bool = false,
    /// Determine how many bytes are needed to be compressed.
    threshold: u16 = 1024,
};

const Experimental = struct {};

pub const Config = struct {
    /// Specifies how large the buffer of bytes to be read should be.
    read_buffer_size: usize = 65535,
    /// Specifies how large a complete message can be.
    max_msg_size: usize = std.math.maxInt(u32),

    /// Compresses the data before sending it to the client (perMessageDeflate).
    permessage_deflate: PerMessageDeflate = .{},

    /// Experimental configurations should only be used for testing purposes.
    experimental: Experimental = .{},
};
