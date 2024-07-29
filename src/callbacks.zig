const std = @import("std");
const SourceLocation = std.builtin.SourceLocation;

const ClientFile = @import("./client.zig");
const Client = ClientFile.Client;
const ErrorFile = @import("./error.zig");
const Error = ErrorFile.Error;

pub const HandshakeFn = ?*const fn (addr: *const std.net.Address, headers: []const u8) anyerror!bool;
pub const ErrorFn = ?*const fn (client: ?*Client, info: *const Error) anyerror!void;

pub const OStrFn = ?*const fn (client: *Client, data: ?[]const u8) anyerror!void;
pub const Fn = ?*const fn (client: *Client) anyerror!void;

pub const Callbacks = struct {
    handshake: HandshakeCallback = .{ .handler = null },
    disconnect: FnCallback = .{ .name = "Disconnect", .handler = null },
    err: ErrorCallback = .{ .handler = null },

    text: OStrCallback = .{ .name = "Text", .handler = null },
    binary: OStrCallback = .{ .name = "Binary", .handler = null },
    close: OStrCallback = .{ .name = "Close", .handler = null },
    ping: OStrCallback = .{ .name = "Ping", .handler = null },
    pong: OStrCallback = .{ .name = "Pong", .handler = null },
};

const HandshakeCallback = struct {
    handler: HandshakeFn,

    const Self = @This();

    pub fn handle(self: *const Self, addr: *const std.net.Address, headers: []const u8) bool {
        if (self.handler != null) {
            const cb_result = self.handler.?(addr, headers) catch |e| {
                std.debug.print("Handshake callback failed: {any}\n", .{e});
                return false;
            };
            return cb_result;
        }
        return true;
    }
};

const ErrorCallback = struct {
    handler: ErrorFn,

    const Self = @This();

    pub fn handle(self: *const Self, client: ?*Client, info: Error) void {
        if (self.handler != null) {
            self.handler.?(client, &info) catch |e| {
                std.debug.print("Error callback failed: {any}\n", .{e});
            };
        }
    }
};

const OStrCallback = struct {
    name: []const u8,
    handler: OStrFn,

    const Self = @This();

    pub fn handle(self: *const Self, client: *Client, data: ?[]const u8) void {
        if (self.handler != null) {
            self.handler.?(client, data) catch |e| {
                std.debug.print("{s} callback failed: {any}\n", .{ self.name, e });
            };
        }
    }
};

const FnCallback = struct {
    name: []const u8,
    handler: Fn,

    const Self = @This();

    pub fn handle(self: *const Self, client: *Client) void {
        if (self.handler != null) {
            self.handler.?(client) catch |e| {
                std.debug.print("{s} callback failed: {any}\n", .{ self.name, e });
            };
        }
    }
};
