const std = @import("std");
const Allocator = std.mem.Allocator;

const FrameFile = @import("./frame.zig");
const Frame = FrameFile.Frame;

pub const Type = enum(u8) {
    Continue = 0,
    Text = 1,
    Binary = 2,
    Close = 8,
    Ping = 9,
    Pong = 10,

    const Self = @This();

    pub fn from(opcode: u8) anyerror!Self {
        return switch (opcode) {
            0 => Type.Continue,
            1 => Type.Text,
            2 => Type.Binary,
            8 => Type.Close,
            9 => Type.Ping,
            10 => Type.Pong,
            else => error.MessageType_Unknown,
        };
    }

    pub inline fn into(self: Self) u8 {
        return @intFromEnum(self);
    }
};

pub const Message = struct {
    allocator: *const Allocator,
    max_msg_size: usize = 0,

    _bytes: ?[]u8 = null,
    _last_message: bool = false,
    _type: Type = Type.Continue,

    const Self = @This();

    pub inline fn get(self: *const Self) ?[]u8 {
        return self._bytes;
    }

    pub inline fn isLastMessage(self: *const Self) bool {
        return self._last_message;
    }

    pub inline fn setLastMessage(self: *Self, value: bool) void {
        self._last_message = value;
    }

    pub inline fn getType(self: *const Self) Type {
        return self._type;
    }

    pub inline fn setType(self: *Self, value: Type) void {
        self._type = value;
    }

    /// This function copies the `bytes`.
    ///
    /// Make sure to free `bytes` when they are no longer needed.
    pub fn addBytes(self: *Self, bytes: []const u8) anyerror!void {
        if (self._bytes == null) {
            self._bytes = try self.allocator.alloc(u8, bytes.len);
        } else {
            const old_bytes_len = self._bytes.?.len;
            if ((old_bytes_len + bytes.len) > self.max_msg_size) {
                return error.MaxMsgSizeExceeded;
            }
            self._bytes = try self.allocator.realloc(self._bytes.?, old_bytes_len + bytes.len);
        }

        @memcpy(self._bytes.?[(self._bytes.?.len - bytes.len)..], bytes);
    }

    pub fn read(self: *Self, buffer: []const u8) anyerror!usize {
        var frame: Frame = .{ .allocator = self.allocator, .bytes = buffer };
        errdefer frame.deinit();

        self._bytes = try frame.read();
        errdefer self._bytes = null;

        self._last_message = frame.isLastFrame();
        self._type = try Type.from(frame.getOpcode());

        return frame.getBytesLeft();
    }

    pub fn write(self: *Self, data: []const u8, compression: bool, compression_threshold: u16) anyerror!void {
        var frame: Frame = .{ .allocator = self.allocator, .bytes = data };
        errdefer frame.deinit();
        frame.setLastFrame(self._last_message);
        frame.setCompression(compression);
        frame.setOpcode(self._type.into());
        self._bytes = try frame.write(compression_threshold);
    }

    pub fn deinit(self: *Self) void {
        if (self._bytes != null) {
            self.allocator.free(self._bytes.?);
        }
        self.* = undefined;
    }
};
