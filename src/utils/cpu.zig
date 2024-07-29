const builtin = @import("builtin");

/// This function checks the architecture used
/// and tells us whether the `u64` data type is supported.
pub inline fn is64bit() bool {
    comptime switch (builtin.cpu.arch) {
        .aarch64,
        .aarch64_be,
        .amdgcn,
        .amdil64,
        .bpfeb,
        .bpfel,
        .hsail64,
        .le64,
        .loongarch64,
        .mips64,
        .mips64el,
        .nvptx64,
        .powerpc64,
        .powerpc64le,
        .renderscript64,
        .riscv64,
        .sparc64,
        .spir64,
        .spirv64,
        .ve,
        .wasm64,
        .x86_64,
        => return true,
        else => return false,
    };
}
