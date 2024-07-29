// Frame format:
//
//       0                   1                   2                   3
//       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
//      +-+-+-+-+-------+-+-------------+-------------------------------+
//      |F|R|R|R|opcode |M| Payload len |    Extended payload length    |
//      |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
//      |N|V|V|V|       |S|             |   (if payload len==126/127)   |
//      | |1|2|3|       |K|             |                               |
//      +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
//      |   Extended payload length continued, if payload len == 127    |
//      + - - - - - - - - - - - - - - - +-------------------------------+
//      |                               | Masking-key, if MASK set to 1 |
//      +-------------------------------+-------------------------------+
//      |    Masking-key (continued)    |          Payload Data         |
//      +-------------------------------- - - - - - - - - - - - - - - - +
//      :                     Payload Data continued ...                :
//      + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
//      |                     Payload Data continued ...                |
//      +---------------------------------------------------------------+
//
// First byte:
// - bit 0:   FIN
// - bit 1:   RSV1
// - bit 2:   RSV2
// - bit 3:   RSV3
// - bit 4-7: OPCODE
// Bytes 2-10: payload length.
// If masking is used, the next 4 bytes contain the masking key.
// All subsequent bytes are payload.

const std = @import("std");
const Allocator = std.mem.Allocator;

const Utils = @import("./utils/lib.zig");

pub const Frame = struct {
    allocator: *const Allocator,
    bytes: []const u8,

    // Bytes that do not belong to this frame.
    _bytes_left: usize = 0,

    _fin: bool = false,
    _rsv1: bool = false, // PerMessageDeflate
    _rsv2: u8 = 0,
    _rsv3: u8 = 0,
    _opcode: u8 = 0,
    _masked: bool = false,

    _payload_len: usize = 0,
    _payload_data: ?[]u8 = null,

    const Self = @This();

    pub inline fn getBytesLeft(self: *const Self) usize {
        return self._bytes_left;
    }

    pub inline fn isLastFrame(self: *const Self) bool {
        return self._fin;
    }

    pub inline fn setLastFrame(self: *Self, state: bool) void {
        self._fin = state;
    }

    pub inline fn setCompression(self: *Self, value: bool) void {
        self._rsv1 = value;
    }

    pub inline fn getOpcode(self: *const Self) u8 {
        return self._opcode;
    }

    pub inline fn setOpcode(self: *Self, value: u8) void {
        self._opcode = value;
    }

    pub fn read(self: *Self) anyerror!?[]u8 {
        try self._parseFlags();
        try self._parsePayload();
        return self._payload_data;
    }

    fn _parseFlags(self: *Self) anyerror!void {
        // Prevent clients from crashing the server with too few bytes.
        if (self.bytes.len < 2) {
            return error.Frame_TooFewBytes;
        }

        // The FIN bit tells whether this is the last message in a series.
        // If it's false, then the server keeps listening for more parts of the message.
        self._fin = (self.bytes[0] & 0b10000000) != 0;
        //std.debug.print("fin: {any}\n", .{self._fin});

        self._rsv1 = (self.bytes[0] & 0b01000000) != 0;
        self._rsv2 = self.bytes[0] & 0b00100000;
        self._rsv3 = self.bytes[0] & 0b00010000;
        //std.debug.print("rsv1: {d}\nrsv2: {d}\nrsv3: {d}\n", .{ self._rsv1, self._rsv2, self._rsv3 });

        // Fragmentation is only available on 0-2.
        // 0 = continue; 1 = text; 2 = binary; 8 = close; 9 = ping; 10 = pong
        self._opcode = self.bytes[0] & 0b00001111;
        //std.debug.print("opcode: {d}\n", .{self._opcode});

        self._masked = (self.bytes[1] & 0b10000000) != 0;
        //std.debug.print("masked: {any}\n", .{self._masked});

        self._payload_len = self.bytes[1] & 0b01111111;
        //std.debug.print("payload length: {any}\n", .{self._payload_len});
    }

    fn _parsePayload(self: *Self) anyerror!void {
        if (self._payload_len == 0) {
            return;
        }

        var extra_len: u8 = 2;
        if (self._payload_len == 126) {
            extra_len += 2;

            if (self.bytes.len < extra_len) {
                // A minimum of 4 bytes is required.
                return error.Frame_TooFewBytes;
            }

            self._payload_len = @as(u16, self.bytes[2]) << 8 | self.bytes[3];
        } else if (self._payload_len == 127) {
            extra_len += 8;

            if (self.bytes.len < extra_len) {
                // A minimum of 10 bytes is required.
                return error.Frame_TooFewBytes;
            }

            if (Utils.CPU.is64bit() == false) {
                // A data type `u64` is required to process this payload.
                return error.Frame_64bitRequired;
            }

            self._payload_len =
                @as(usize, self.bytes[2]) << 56 |
                @as(usize, self.bytes[3]) << 48 |
                @as(usize, self.bytes[4]) << 40 |
                @as(usize, self.bytes[5]) << 32 |
                @as(usize, self.bytes[6]) << 24 |
                @as(usize, self.bytes[7]) << 16 |
                @as(usize, self.bytes[8]) << 8 |
                @as(usize, self.bytes[9]);
        }

        var masking_key: ?[]const u8 = null;
        if (self._masked == true) {
            extra_len += 4;

            if (self.bytes.len < extra_len) {
                // A minimum of 6|8|12 bytes is required.
                return error.Frame_TooFewBytes;
            }

            masking_key = self.bytes[(extra_len - 4)..extra_len];
        }

        const bytes_calc: usize = self.bytes.len - extra_len;
        if (bytes_calc < self._payload_len) {
            // This can happen if `read_buffer_size` is set too low and not all bytes are read.
            return error.Frame_MissingBytes;
        } else if (bytes_calc > self._payload_len) {
            // Do we have more than just one message in the bytes?
            self._bytes_left = bytes_calc - self._payload_len;
        }

        self._payload_data = try self.allocator.alloc(u8, self._payload_len);
        @memcpy(self._payload_data.?, self.bytes[(extra_len)..(extra_len + self._payload_len)]);

        if (masking_key != null) {
            for (0..self._payload_data.?.len) |i| {
                self._payload_data.?[i] ^= masking_key.?[i % 4];
            }
        }

        if (self._rsv1 == true) {
            // If there is only one byte (0x00), this is the end of the compressed data.
            if (self._payload_len <= 1) {
                self.allocator.free(self._payload_data.?);
                self._payload_data = null;
                return;
            }

            const old_payload = self._payload_data.?;
            defer self.allocator.free(old_payload);

            // Set missing bfinal bit.
            old_payload[0] |= 0b00000001;
            self._payload_data = try self._decompress(old_payload);
        }
    }

    noinline fn _decompress(self: *const Self, data: []const u8) anyerror![]u8 {
        var data_stream = std.io.fixedBufferStream(data);
        var result = std.ArrayList(u8).init(self.allocator.*);
        defer result.deinit();
        try std.compress.flate.decompress(data_stream.reader(), result.writer());
        return try result.toOwnedSlice();
    }

    noinline fn _compress(self: *const Self, data: []const u8) anyerror![]u8 {
        var data_stream = std.io.fixedBufferStream(data);
        var result = std.ArrayList(u8).init(self.allocator.*);
        defer result.deinit();
        try std.compress.flate.compress(data_stream.reader(), result.writer(), .{});
        return try result.toOwnedSlice();
    }

    pub fn write(self: *Self, compression_threshold: u16) anyerror![]u8 {
        var free_bytes = false;
        defer {
            if (free_bytes == true) {
                self.allocator.free(self.bytes);
            }
        }

        var result = std.ArrayList(u8).init(self.allocator.*);
        defer result.deinit();

        try result.append(self._opcode);

        if (self._fin == true) {
            result.items[0] |= 0b10000000;
        }
        if (self._rsv1 == true) {
            if (self.bytes.len >= compression_threshold) {
                result.items[0] |= 0b01000000;

                self.bytes = try self._compress(self.bytes);
                free_bytes = true;
            }
        }

        if (self.bytes.len <= 125) {
            try result.appendNTimes(0, 1);

            result.items[1] = @intCast(self.bytes.len);
        } else if (self.bytes.len <= 65531) {
            try result.appendNTimes(0, 3);

            result.items[1] = 126;
            result.items[2] = @intCast((self.bytes.len >> 8) & 0b11111111);
            result.items[3] = @intCast(self.bytes.len & 0b11111111);
        } else {
            if (Utils.CPU.is64bit() == false) {
                // A data type `u64` is required to process this payload.
                return error.Frame_64bitRequired;
            }

            try result.appendNTimes(0, 9);

            result.items[1] = 127;
            result.items[2] = @intCast((self.bytes.len >> 56) & 0b11111111);
            result.items[3] = @intCast((self.bytes.len >> 48) & 0b11111111);
            result.items[4] = @intCast((self.bytes.len >> 40) & 0b11111111);
            result.items[5] = @intCast((self.bytes.len >> 32) & 0b11111111);
            result.items[6] = @intCast((self.bytes.len >> 24) & 0b11111111);
            result.items[7] = @intCast((self.bytes.len >> 16) & 0b11111111);
            result.items[8] = @intCast((self.bytes.len >> 8) & 0b11111111);
            result.items[9] = @intCast(self.bytes.len & 0b11111111);
        }

        try result.appendSlice(self.bytes);
        self._payload_data = try result.toOwnedSlice();
        return self._payload_data.?;
    }

    pub fn deinit(self: *Self) void {
        if (self._payload_data != null) {
            self.allocator.free(self._payload_data.?);
        }
        self.* = undefined;
    }
};
