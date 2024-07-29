const std = @import("std");

const ws = @import("ws-server");
const Server = ws.Server;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var server = Server.create(&allocator, "127.0.0.1", 8080);
    server.setConfig(.{
        // Specifies how large the buffer of bytes to be read should be.
        .read_buffer_size = 4096, // default: 65535
        // Specifies how large a complete message can be.
        .max_msg_size = 12288, // default: std.math.maxInt(u32)

        // Compresses the data before sending it to the client (perMessageDeflate).
        .permessage_deflate = .{
            // Set this value to true to compress data before sending.
            .enabled = true, // default: false
            // Determine how many bytes are needed to be compressed.
            .threshold = 512, // default: 1024
        },
    });
    try server.listen();
}
