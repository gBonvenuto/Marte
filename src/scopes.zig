const std = @import("std");
const hashmap = @import("./varhashmap.zig");
const stack = @import("./stack.zig");

const Scope = struct {
    varhashmap: hashmap.VariablesHashMap,
    start: usize, // índice do token inícial
    end: usize, // índice do token final
};
