# Changelog
## [v0.6.1](https://github.com/ws-zig/ws-server/tree/v0.6.1) (2024-04-29 UTC+1)
> [!NOTE]
> The current Zig(-lang) version [**0.12.0**](https://github.com/ziglang/zig/releases/tag/0.12.0) is supported.

**Added**
- `Error.getSymbolInfo()` for debug informations about the current error.
- - This function contains some information about the file, line and more where this error was returned.

**Fixed**
- a connection is not closed properly if the handshake result is `false` or causes an error.

**Other**
- Handshake: Performance has been significantly improved.
- - A benchmark showed an improvement of ~24% (~3334 vs ~4389 sessions per second).
- Message: Read and write performance has been improved.
- - A benchmark with 100 clients showed an improvement of:
  - received: ~10.4% (13096 vs 14608 messages per second).
  - sent: ~10.4% (13098 vs 14611 messages per second).
- Some other improvements.
- -  [Click here to compare all changes.](https://github.com/ws-zig/ws-server/compare/v0.6.0...v0.6.1)

## [v0.6.0](https://github.com/ws-zig/ws-server/tree/v0.6.0) (2024-04-25 UTC+1)
> [!NOTE]
> The current Zig(-lang) version [**0.12.0**](https://github.com/ziglang/zig/releases/tag/0.12.0) is supported.

**Changed**
- `config.experimental.compression` in `config.permessage_deflate`.
- - This server configuration has been changed with our new `PerMessageDeflate` struct in `config.permessage_deflate`.

**Removed**
- `textAll()` and `binaryAll()`.
- - These functions have been replaced by the new `options` parameter for `text()` and `binary()`.
  - Messages with the message type `Continue` can now be sent regardless of the number of bytes.
- Forgotten `std.debug.print()` console print from `v0.5.0`.

**Added**
- `permessage_deflate` and `handshake` for server configurations.
- - `permessage_deflate`:
  - `enabled`: Set this value to true to compress data before sending.
  - `threshold`: Determine how many bytes are needed to be compressed.
- - `handshake`:
  - `header_limit`: As soon as the client has more headers than this value, the handshake is aborted.
- `method` and `uri` parameters for the handshake callback.
- support for incoming messages with the message type `Continue`.
- `data` parameter for close, ping and pong callback.
- `options` parameter for `text()` and `binary()`.
- - This new parameter can be a struct or null.
  - `struct`: Configurations such as compression for this message can be overridden.
  - `null`: All default configurations are used for this message.

**Fixed**
- memory leak when an error occurs while processing incoming messages.

**Other**
- The header extension `client_no_context_takeover` is now sent back when `permessage-deflate` is received.
- - It is needed to decompress the messages.
- Many improvements.
- -  [Click here to compare all changes.](https://github.com/ws-zig/ws-server/compare/v0.5.0...v0.6.0)

## [v0.5.0](https://github.com/ws-zig/ws-server/tree/v0.5.0) (2024-04-22 UTC+1)
> [!NOTE]
> The current Zig(-lang) version [**0.12.0**](https://github.com/ziglang/zig/releases/tag/0.12.0) is supported.

**Changed**
- `LICENSE` has been changed from `Apache License` to `MIT License`.
- `msg_buffer_size` has been renamed to `read_buffer_size`.
- If `compression = true`, the data is only compressed if it is longer than 1023 bytes (default threshold).
- Handshake.
- - `permessage-deflate` also required the `client_no_context_takeover` header.
- Receiving "Message Continuation" has been temporarily removed.

**Added**
- `build.zig.zon`.
- - For Zig(-lang) `0.12.0`.
- `CloseCodes`.
- - An `enum(u16)` for the new function `closeExpanded()`.
- `closeExpanded()`.
- - An alternative to `close()`.
- 64bit support for the following architectures:
- - `amdgcn`, `amdil64`, `bpfeb`, `bpfel`, `hsail64`, `le64`, `loongarch64`, `mips64`, `mips64el`, `nvptx64`, `powerpc64`, `powerpc64le`, `renderscript64`, `riscv64`, `sparc64`, `spir64`, `spirv64`, `ve`, `wasm64`.

**Fixed**
- `ping()`, `pong()`, `close()`.
- - These functions should be sent without compression.
- Unexpected error was fixed when the payload was larger than the length of the bytes.
- Multiple messages in the buffer are now processed separately.
- - If multiple messages were in the buffer at the same time, only the first message was processed.

**Other**
- Some improvements.
- -  [Click here to compare all changes.](https://github.com/ws-zig/ws-server/compare/v0.4.0...v0.5.0)

## [v0.4.0](https://github.com/ws-zig/ws-server/tree/v0.4.0) (2024-03-10 UTC+1)
> [!NOTE]
> The upcoming Zig(-lang) version [**0.12.0**](https://github.com/ziglang/zig/tree/0b744da844e4172ec0c695098e67ab2a7184c5f0) is supported.

> [!TIP]
> Check out the new source code for our [examples](https://github.com/ws-zig/ws-server/tree/v0.4.0/examples).

**Changed**
- `text()`, `textAll()`, `binary()`, `binaryAll()`, `ping()` and `pong()` now return a boolean value.
- - This value indicates whether the message was sent, otherwise the client is no longer connected to the server.
- `onError` callback now has an `Error` struct parameter.
- - This new struct now contains all information.
- `buffer_size` configuration.
- - This configuration has been renamed to `msg_buffer_size`.

**Added**
- `max_msg_size` configuration.
- - If the message is received in "chunks" and exceeds this limit, the `onError` callback is called and the client is disconnected.
  - Default: `std.math.maxInt(u32)`

**Fixed**
- `ping()`, `pong()` and empty `text()`, `textAll()`, `binary()` and `binaryAll()` when compression is enabled.
- - Empty messages caused an error on the client side.

**Other**
- Some improvements and a rewritten handshake.
- -  [Click here to compare all changes.](https://github.com/ws-zig/ws-server/compare/v0.3.0...v0.4.0)

## [v0.3.0](https://github.com/ws-zig/ws-server/tree/v0.3.0) (2024-03-05 UTC+1)
> [!NOTE]
> The upcoming Zig(-lang) version [**0.12.0**](https://github.com/ziglang/zig/tree/0b744da844e4172ec0c695098e67ab2a7184c5f0) is supported.

**Changed**
- The required Zig(-lang) version has been increased to **0.12.0**.
- The callback argument `data: []const u8` has been changed to `data: ?[]const u8`.

**Added**
- `experimental` server configuration.
- - All experimental configurations should only be used for testing purposes!
- [Experimental] Support for compression (perMessageDeflate).
- - Use `server.setConfig(.{ .experimental = .{ .compression = true } })` to enable compression.
  - The header `Sec-WebSocket-Extensions: permessage-deflate` is required during the handshake, otherwise the client will be disconnected!

**Other**
- Many improvements, bug fixes and more.
- - [Click here to compare all changes.](https://github.com/ws-zig/ws-server/compare/v0.2.1...v0.3.0)

## [v0.2.1](https://github.com/ws-zig/ws-server/tree/v0.2.1) (2024-03-04 UTC+1)
> [!NOTE]
> The current Zig(-lang) version [**0.11.0**](https://github.com/ziglang/zig/releases/tag/0.11.0) is supported.

**Fixed**
- Send and receive large data on `AArch64`.
- - With v0.2.0 we only checked `x86_64` for data type `u64`.
- `text()` and `binary()` with exactly 65531 bytes.
- - Data with exactly 65531 bytes never arrived at the client marked as complete.
- `textAll()` and `binaryAll()` with to large data and unsupported data type `u64`.
- - The data is now automatically sent to the client as "chunks" if the size is over 65531 bytes and the data type `u64` is not supported.

**Known issues**
- Console error on Windows when client disconnects.
- - An error message is displayed in the console which can be ignored. The error is only displayed if the client disconnects during a callback. The problem was fixed with Zig(-lang) in version 0.12.0.

## [v0.2.0](https://github.com/ws-zig/ws-server/tree/v0.2.0) (2024-02-29 UTC+1)
> [!NOTE]
> The current Zig(-lang) version [**0.11.0**](https://github.com/ziglang/zig/releases/tag/0.11.0) is supported.

**Changed**
- `sendText()`
- - This function is now called `text()`. The data is now sent in chunks (65535 bytes each).
- `sendBinary()`
- - This function is now called `binary()`. The data is now sent in chunks (65535 bytes each).
- `sendClose()`
- - This function is now called `close()`.
- `sendPing()`
- - This function is now called `ping()`.
- `sendPong()`
- - This function is now called `pong()`.

**Added**
- Support for sending large messages as multiple small ones.
- - Data longer than 65531 bytes is sent as "chunks", meaning the server sends multiple messages containing parts of the large message with a maximum of 65535 bytes (the client processes the messages as one complete once the last one is received).
- `textAll()`
- - This function replaces the previous `sendText()`.
- `binaryAll()`
- - This function replaces the previous `sendBinary()`.

**Fixed**
- Compiling for 32-bit architectures was not possible and resulted in an error.
- - The `text()` or `binary()` function should be used for 32-bit architectures with more than 65531 bytes of data. Also make sure that no more than 65535 bytes (65531 bytes + frame) are sent from the client at once. Anything over 65535 bytes (65531 bytes + frame) of data requires 64-bit architecture (u64 data type).

**Other**
- General improvements.

## [v0.1.0](https://github.com/ws-zig/ws-server/tree/v0.1.0) (2024-02-27 UTC+1)
> [!NOTE]
> The current Zig(-lang) version [**0.11.0**](https://github.com/ziglang/zig/releases/tag/0.11.0) is supported.
