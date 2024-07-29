const std = @import("std");

pub const Error = struct {
    _error: anyerror,
    _stack_trace: ?*std.builtin.StackTrace,

    const Self = @This();

    pub inline fn getError(self: *const Self) anyerror {
        return self._error;
    }

    /// `SymbolInfo` contains more details about this error such as the name of the file in which this error occurred.
    ///
    /// To avoid memory leaks, `deinit()` should be executed after this function call.
    ///
    /// **IMPORTANT:** This information is only available in "debug"!
    pub fn getSymbolInfo(self: *const Self) ?std.debug.SymbolInfo {
        if (self._stack_trace == null) {
            return null;
        }
        const addr = self._stack_trace.?.instruction_addresses[0];

        const debug_info = std.debug.getSelfDebugInfo() catch return null;

        const module = debug_info.*.getModuleForAddress(addr) catch return null;
        const symbol_info = module.getSymbolAtAddress(debug_info.*.allocator, addr) catch return null;
        return symbol_info;
    }

    /// Only required if `getSymbolInfo()` returned a value.
    pub fn deinit(_: *const Self, symbol_info: *const std.debug.SymbolInfo) void {
        const debug_info = std.debug.getSelfDebugInfo() catch return;
        symbol_info.deinit(debug_info.*.allocator);
    }
};
