const std = @import("std");
const Allocator = std.mem.Allocator;
const PosixReadError = std.posix.ReadError;

const ConfigFile = @import("./config.zig");
const PerMessageDeflate = ConfigFile.PerMessageDeflate;
const MessageFile = @import("./message.zig");
const Message = MessageFile.Message;
const MessageType = MessageFile.Type;
const CallbacksFile = @import("./callbacks.zig");
const Callbacks = CallbacksFile.Callbacks;

pub const CloseCodes = enum(u16) {
    Normal = 1000,
    GoingAway = 1001,
    ProtocolError = 1002,
    Unsupported = 1003,
    _Reserved1 = 1004,
    NoStatus = 1005,
    Abnormal = 1006,
    UnsupportedPayload = 1007,
    PolicyViolation = 1008,
    TooLarge = 1009,
    MandatoryExtension = 1010,
    ServerError = 1011,
    ServiceRestart = 1012,
    TryAgainLater = 1013,
    BadGateway = 1014,
    TlsHandshakeFail = 1015,
};

const PrivateFields = struct {
    allocator: *const std.mem.Allocator,
    callbacks: *const Callbacks,
    connection: *const std.net.Server.Connection,
    permessage_deflate: *const PerMessageDeflate,

    // true = Stop the message receiving loop
    close_conn: bool = false,
};

pub const Client = struct {
    /// Private data that should not be touched.
    _private: PrivateFields,

    const Self = @This();

    // Just a helper function to reduce code length.
    inline fn useCompression(self: *const Self) bool {
        return self._private.permessage_deflate.enabled;
    }

    // Just a helper function to reduce code length.
    inline fn compressionThreshold(self: *const Self) u16 {
        return self._private.permessage_deflate.threshold;
    }

    /// Get the client's address from the stream.
    pub inline fn getAddress(self: *const Self) std.net.Address {
        return self._private.connection.address;
    }

    /// This function writes `data` to this client's stream.
    ///
    /// __returns:__ `false` if the connection to this client has been lost.
    fn _writeAll(self: *const Self, data: []const u8) anyerror!bool {
        self._private.connection.stream.writeAll(data) catch |e| {
            // The connection was closed by the client.
            if (e == error.ConnectionResetByPeer) {
                return false;
            }
            return e;
        };
        return true;
    }

    const _sendOptions = struct {
        /// If the value is `true` the standard message type is used, otherwise `Continue`.
        first_message: bool = true,
        /// `true` if all data in this message has been sent to the client and can now be processed.
        last_message: bool = true,
        /// Override the `config.permessage_deflate.enabled` configuration for this message.
        ///
        /// __null__: Use server configuration.
        ///
        /// __true__: Use compression.
        ///
        /// __false__: Do not use compression.
        compression: ?bool = null,
    };

    /// Sends `data` to the client.
    ///
    /// __returns:__ `false` if the connection to this client has been lost.
    fn _send(self: *const Self, m_type: MessageType, data: []const u8, options: *const ?_sendOptions) anyerror!bool {
        var message: Message = .{ .allocator = self._private.allocator };
        defer message.deinit();

        if (options.*) |*opts| {
            message.setLastMessage(opts.*.last_message);

            if (opts.*.first_message == false) {
                message.setType(MessageType.Continue);
            } else {
                message.setType(m_type);
            }

            const compression = opts.*.compression orelse self.useCompression();
            try message.write(data, compression, self.compressionThreshold());
        } else {
            message.setLastMessage(true);
            message.setType(m_type);
            try message.write(data, self.useCompression(), self.compressionThreshold());
        }

        return try self._writeAll(message.get().?);
    }

    /// Sends `data` with the "Text" message type to the client.
    ///
    /// __returns:__ `false` if the connection to this client has been lost.
    pub fn text(self: *const Self, data: []const u8, options: ?_sendOptions) anyerror!bool {
        return try self._send(MessageType.Text, data, &options);
    }

    /// Sends `data` with the "Binary" message type to the client.
    ///
    /// __returns:__ `false` if the connection to this client has been lost.
    pub fn binary(self: *const Self, data: []const u8, options: ?_sendOptions) anyerror!bool {
        return try self._send(MessageType.Binary, data, &options);
    }

    /// Sends `data` with the "Close" message type to the client.
    ///
    /// If `data` is `null`, only the message without content will be sent.
    ///
    /// **IMPORTANT:** The connection will only be closed when the client sends this message back.
    ///
    /// __returns:__ `false` if the connection to this client has been lost.
    pub fn close(self: *const Self, data: ?[]const u8) anyerror!bool {
        return try self.closeExpanded(CloseCodes.Normal, data);
    }

    /// Sends `data` with the "Close" message type to the client.
    ///
    /// If `data` is `null`, only the message with the closing code `code` but without content will be sent.
    ///
    /// **IMPORTANT:** The connection will only be closed when the client sends this message back.
    ///
    /// __returns:__ `false` if the connection to this client has been lost.
    pub fn closeExpanded(self: *const Self, code: CloseCodes, data: ?[]const u8) anyerror!bool {
        var data_result: ?[]u8 = null;
        defer {
            if (data_result != null) {
                self._private.allocator.free(data_result.?);
            }
        }

        if (data != null) {
            data_result = try self._private.allocator.alloc(u8, (2 + data.?.len));
            @memcpy(data_result.?[2..], data.?);
        } else {
            data_result = try self._private.allocator.alloc(u8, 2);
        }
        const code_val: u16 = @intFromEnum(code);
        data_result.?[0] = @intCast((code_val >> 8) & 0b11111111);
        data_result.?[1] = @intCast(code_val & 0b11111111);

        return try self._send(MessageType.Close, data_result.?, &.{ .compression = false });
    }

    /// Close the connection from this client immediately.
    /// (No "close" message is sent to the client!)
    pub fn closeImmediately(self: *Self) void {
        self._private.close_conn = true;
    }

    /// Sends `data` with the "Ping" message type to the client.
    ///
    /// If `data` is `null`, only the message without content will be sent.
    ///
    /// __returns:__ `false` if the connection to this client has been lost.
    pub fn ping(self: *const Self, data: ?[]const u8) anyerror!bool {
        if (data != null) {
            return try self._send(MessageType.Ping, data.?, &.{ .compression = false });
        }
        return try self._send(MessageType.Ping, "", &.{ .compression = false });
    }

    /// Sends `data` with the "Pong" message type to the client.
    ///
    /// If `data` is `null`, only the message without content will be sent.
    ///
    /// __returns:__ `false` if the connection to this client has been lost.
    pub fn pong(self: *const Self, data: ?[]const u8) anyerror!bool {
        if (data != null) {
            return try self._send(MessageType.Pong, data.?, &.{ .compression = false });
        }
        return try self._send(MessageType.Pong, "", &.{ .compression = false });
    }
};

pub fn handle(self: *Client, read_buffer_size: usize, max_msg_size: usize) anyerror!void {
    defer self._private.callbacks.disconnect.handle(self);

    var messages = std.ArrayList(?Message).init(self._private.allocator.*);
    defer {
        for (0..messages.items.len) |idx| {
            if (messages.items[idx] != null) {
                messages.items[idx].?.deinit();
            }
        }
        messages.deinit();
    }

    while (self._private.close_conn == false) {
        var buffer = try self._private.allocator.alloc(u8, read_buffer_size);
        defer free_defer: {
            self._private.allocator.free(buffer);

            for (0..messages.items.len) |idx| {
                if (messages.items[idx] != null) {
                    // This only happens if we have received an incomplete "continue" message.
                    break :free_defer;
                }
            }
            messages.clearAndFree();
        }

        const buffer_len = self._private.connection.stream.read(buffer) catch |e| {
            switch (e) {
                // The connection was not closed properly by this client.
                PosixReadError.ConnectionResetByPeer, PosixReadError.ConnectionTimedOut, PosixReadError.SocketNotConnected => return,
                // Something went wrong ...
                else => return e,
            }
        };

        try _bytesToMessage(self, buffer[0..buffer_len], &messages, max_msg_size);
        _handleMessages(self, &messages);
    }
}

fn _bytesToMessage(self: *const Client, buffer: []u8, messages: *std.ArrayList(?Message), max_msg_size: usize) anyerror!void {
    var buffer_idx: usize = 0;
    outer_loop: while (buffer_idx < buffer.len) {
        var temp_message: Message = .{ .allocator = self._private.allocator, .max_msg_size = max_msg_size };
        errdefer temp_message.deinit();

        const bytes_left = try temp_message.read(buffer[buffer_idx..]);
        buffer_idx = buffer.len - bytes_left;

        switch (temp_message.getType()) {
            MessageType.Continue => {
                // The bytes are copied and `temp_message`
                // is no longer needed after this loop.
                defer temp_message.deinit();

                if (messages.items.len == 0) {
                    // Should never be the first message.
                    return error.MessageContinue_LastMessageIsMissing;
                }

                const last_message = &messages.items[(messages.items.len - 1)];

                if (last_message.*.?.getType() != MessageType.Text and last_message.*.?.getType() != MessageType.Binary) {
                    // Only "Text" and "Binary" should support it.
                    return error.MessageContinue_WrongLastMessageType;
                }
                if (last_message.*.?.isLastMessage() == true) {
                    // The message `last_message` should not be complete yet.
                    return error.MessageContinue_LastMessageNotExpected;
                }

                try last_message.*.?.addBytes(temp_message.get().?);
                last_message.*.?.setLastMessage(temp_message.isLastMessage());

                // We don't want to add `temp_message` in `messages`,
                // so we continue this loop.
                continue :outer_loop;
            },
            MessageType.Text, MessageType.Binary => {
                // Do nothing
            },
            MessageType.Close, MessageType.Ping, MessageType.Pong => {
                if (temp_message.isLastMessage() == false) {
                    // Should contain no data or only a small piece
                    // of information and therefore be the last message.
                    return error.LastMessageExpected;
                }
            },
        }

        // Finally, we add `temp_message` to `messages`.
        try messages.append(temp_message);
    }
}

fn _handleMessages(self: *Client, messages: *std.ArrayList(?Message)) void {
    for (messages.items[0..]) |*message| {
        if (message.*.?.isLastMessage() == false) {
            // We are still waiting for this message to be completed ...
            continue;
        }

        switch (message.*.?.getType()) {
            MessageType.Continue => {
                // Messages with the type "Continue" are never added
                // to `messages` and therefore do not exist here.
                unreachable;
            },
            MessageType.Text => { // Process received text message...
                self._private.callbacks.text.handle(self, message.*.?.get());
            },
            MessageType.Binary => { // Process received binary message...
                self._private.callbacks.binary.handle(self, message.*.?.get());
            },
            MessageType.Close => { // The client sends us a "close" message, so he wants to disconnect properly.
                self._private.callbacks.close.handle(self, message.*.?.get());
                // Either the loop is terminated using `closeImmediately()`
                // or the loop is terminated by actually breaking the connection.
                // So we don't have to return anything.
            },
            MessageType.Ping => { // "Hello server, are you there?"
                self._private.callbacks.ping.handle(self, message.*.?.get());
            },
            MessageType.Pong => { // "Hello server, here I am"
                self._private.callbacks.pong.handle(self, message.*.?.get());
            },
        }

        message.*.?.deinit();
        message.* = null;
    }
}
