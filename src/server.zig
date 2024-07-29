const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;

const Utils = @import("./utils/lib.zig");
const ConfigFile = @import("./config.zig");
const Config = ConfigFile.Config;
const ClientFile = @import("./client.zig");
const Client = ClientFile.Client;
const Handshake = @import("./handshake.zig");
const CallbacksFile = @import("./callbacks.zig");
const Callbacks = CallbacksFile.Callbacks;

const PrivateFields = struct {
    allocator: *const Allocator,
    addr: []const u8,
    port: u16,

    config: Config = .{},

    callbacks: Callbacks = .{},
};

pub const Server = struct {
    /// Private data that should not be touched.
    _private: PrivateFields,

    const Self = @This();

    /// Create a new server to connect to.
    pub fn create(allocator: *const Allocator, addr: []const u8, port: u16) Self {
        return .{ ._private = .{ .allocator = allocator, .addr = addr, .port = port } };
    }

    /// Use this function to set custom configurations.
    ///
    /// ### Example
    /// ```zig
    /// server.setConfig(.{
    ///     .permessage_deflate = .{
    ///         .enabled = true,
    ///     },
    /// });
    /// ```
    pub fn setConfig(self: *Self, config: Config) void {
        self._private.config = config;
    }

    /// Listen (run) the server.
    pub fn listen(self: *Self) anyerror!void {
        if (self._private.config.read_buffer_size > 65535) {
            if (Utils.CPU.is64bit() == false) {
                // On non-64-bit architectures,
                // you cannot process messages larger than 65535 bytes.
                // To prevent unexpected behavior, the size of the buffer should be reduced.
                return error.MsgBufferSizeExceeded;
            }
        }
        if (self._private.config.max_msg_size < self._private.config.read_buffer_size) {
            // The `max_msg_size` must equal to or be larger than `read_buffer_size`.
            return error.MaxMsgSizeTooLow;
        }

        const address = try net.Address.parseIp(self._private.addr, self._private.port);
        var server = try address.listen(.{});
        defer server.deinit();

        while (true) {
            const connection = server.accept() catch |e| {
                self._private.callbacks.err.handle(null, .{
                    ._error = e,
                    ._stack_trace = @errorReturnTrace(),
                });
                continue;
            };
            errdefer connection.stream.close();

            const thread = std.Thread.spawn(.{}, _clientThread, .{ self, connection }) catch |e| {
                self._private.callbacks.err.handle(null, .{
                    ._error = e,
                    ._stack_trace = @errorReturnTrace(),
                });
                continue;
            };
            thread.detach();
        }
    }

    fn _clientThread(self: *const Self, connection: net.Server.Connection) void {
        defer connection.stream.close();

        self._handleClient(&connection) catch |e| {
            self._private.callbacks.err.handle(null, .{
                ._error = e,
                ._stack_trace = @errorReturnTrace(),
            });
        };
    }

    fn _handleClient(self: *const Self, connection: *const net.Server.Connection) anyerror!void {
        const handshake_accepted = try Handshake.handle(self._private.allocator, connection, &self._private.callbacks);
        if (handshake_accepted == false) {
            return;
        }

        var client: Client = .{
            ._private = .{
                .allocator = self._private.allocator,
                .callbacks = &self._private.callbacks,
                .connection = connection,
                .permessage_deflate = &self._private.config.permessage_deflate,
            },
        };
        try ClientFile.handle(&client, self._private.config.read_buffer_size, self._private.config.max_msg_size);
    }

    /// This function is called whenever a new connection to the server is established.
    ///
    /// **IMPORTANT:** Return `false` and the connection will be closed immediately.
    ///
    /// ### Example
    /// ```zig
    /// fn _onHandshake(addr: *const std.net.Address, headers: []const u8) anyerror!bool {
    ///     // ...
    /// }
    /// ```
    pub fn onHandshake(self: *Self, cb: CallbacksFile.HandshakeFn) void {
        self._private.callbacks.handshake.handler = cb;
    }

    /// This function is always called shortly before the connection to the client is closed.
    ///
    /// ### Example
    /// ```zig
    /// fn _onDisconnect(client: *Client) anyerror!void {
    ///     // ...
    /// }
    /// ```
    pub fn onDisconnect(self: *Self, cb: CallbacksFile.Fn) void {
        self._private.callbacks.disconnect.handler = cb;
    }

    /// This function is called whenever an unexpected error occurs.
    ///
    /// ### Example
    /// ```zig
    /// fn _onError(client: ?*Client, info: *const Error) anyerror!void {
    ///     // ...
    /// }
    /// ```
    pub fn onError(self: *Self, cb: CallbacksFile.ErrorFn) void {
        self._private.callbacks.err.handler = cb;
    }

    /// Set a callback when a "text" message is received from the client.
    ///
    /// ### Example
    /// ```zig
    /// fn _onText(client: *Client, data: ?[]const u8) anyerror!void {
    ///     // ...
    /// }
    /// ```
    pub fn onText(self: *Self, cb: CallbacksFile.OStrFn) void {
        self._private.callbacks.text.handler = cb;
    }

    /// Set a callback when a "binary" message is received from the client.
    ///
    /// ### Example
    /// ```zig
    /// fn _onBinary(client: *Client, data: ?[]const u8) anyerror!void {
    ///     // ...
    /// }
    /// ```
    pub fn onBinary(self: *Self, cb: CallbacksFile.OStrFn) void {
        self._private.callbacks.binary.handler = cb;
    }

    /// Set a callback when a "close" message is received from the client.
    ///
    /// ### Example
    /// ```zig
    /// fn _onClose(client: *Client, data: ?[]const u8) anyerror!void {
    ///     // ...
    /// }
    /// ```
    pub fn onClose(self: *Self, cb: CallbacksFile.OStrFn) void {
        self._private.callbacks.close.handler = cb;
    }

    /// Set a callback when a "ping" message is received from the client.
    ///
    /// ### Example
    /// ```zig
    /// fn _onPing(client: *Client, data: ?[]const u8) anyerror!void {
    ///     // ...
    /// }
    /// ```
    pub fn onPing(self: *Self, cb: CallbacksFile.OStrFn) void {
        self._private.callbacks.ping.handler = cb;
    }

    /// Set a callback when a "pong" message is received from the client.
    ///
    /// ### Example
    /// ```zig
    /// fn _onPong(_: *Client, data: ?[]const u8) anyerror!void {
    ///     // ...
    /// }
    /// ```
    pub fn onPong(self: *Self, cb: CallbacksFile.OStrFn) void {
        self._private.callbacks.pong.handler = cb;
    }
};
