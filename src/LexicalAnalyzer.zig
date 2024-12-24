const std = @import("std");

/// Este struct possui diversas funções para análise lexical
pub const Lex = struct {
    pub const Keywords = enum {
        @"if",
        then,
        @"else",
    };
    pub const Token = struct {
        value: *void,
        type: Types,
        pub const Types = enum {
            integer,
            float,
            char,
            op,
            keyword,
        };
        pub fn print(self: Token) !void {
            switch (self.type) {
                .integer => {
                    const value: *usize = @alignCast(@ptrCast(self.value));
                    std.debug.print("token: {any}, value: {d}\n", .{ self, value.* });
                },
                .float => {
                    const value: *f32 = @alignCast(@ptrCast(self.value));
                    std.debug.print("token: {any}, value: {e}\n", .{ self, value.* });
                },
                else => return error.UnknownType
            }
        }
    };

    pub fn numbers(content: []const u8, initial_index: usize, allocator: std.mem.Allocator) !struct { token: Token, index: usize } {
        var index = initial_index;
        var tok_type = Token.Types.integer;

        var value: usize = 0;
        while (index < content.len and std.ascii.isDigit(content[index])) : (index += 1) {
            value *= 10;
            value += content[index] - '0';
        }

        // Se tiver um ponto, então é um float e devemos continuar lendo
        if (index < content.len and content[index] == '.') {
            var decimal_value_i: usize = 0;
            const point_index = index;
            index += 1;
            if (!std.ascii.isDigit(content[index])) {
                return error.FloatMalformed;
            }
            while (index < content.len and std.ascii.isDigit(content[index])) : (index += 1) {
                decimal_value_i *= 10;
                decimal_value_i += content[index] - '0';
            }

            const decimal_value: f32 = @floatFromInt(decimal_value_i);
            const div: f32 = @floatFromInt(index - point_index);
            const value_f: f32 = @floatFromInt(value);
            const decimal_float: f32 = (decimal_value / std.math.pow(f32, 10, div - 1)) + value_f;

            tok_type = Token.Types.float;
            const tok_value = try allocator.create(f32);
            tok_value.* = decimal_float;
            return .{ .token = Token{
                .value = @ptrCast(tok_value),
                .type = tok_type,
            }, .index = index - 1 };
        }
        // Caso contrário é um inteiro e já lemos tudo
        else {
            const tok_value = try allocator.create(usize);
            tok_value.* = value;
            return .{ .token = Token{
                .value = @ptrCast(tok_value),
                .type = tok_type,
            }, .index = index - 1 };
        }
    }

    pub fn operators(content: []const u8, initial_index: usize, allocator: std.mem.Allocator) !Token {
        const value = try allocator.create(u8);

        return switch (content[initial_index]) {
            '+', '-', '*', '/' => |op_char| blk: {
                value.* = op_char;
                break :blk Token{ .value = @ptrCast(value), .type = Token.Types.op };
            },
            else => error.UnknownOp,
        };
    }
};
