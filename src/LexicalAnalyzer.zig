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
    };

    //TODO:
    // pub fn print(token: Token) void {
    //
    // }
    
    pub fn numbers(content: []const u8, initial_index: usize, allocator: std.mem.Allocator) !struct { token: Token, index: usize } {
        var index = initial_index;
        var tok_type = Token.Types.integer;

        var value: usize = 0;
        while (std.ascii.isDigit(content[index])) : (index = index + 1) {
            value *= 10;
            value += content[index] - '0';
        }

        // Se tiver um ponto, então é um float e devemos continuar lendo
        if (content[index] == '.') {
            var decimal_value_i: usize = 0;
            const point_index = index;
            index += 1;
            if (!std.ascii.isDigit(content[index])) {
                return error.FloatMalformed;
            }
            while (std.ascii.isDigit(content[index])) : (index += 1) {
                decimal_value_i *= 10;
                decimal_value_i += content[index] - '0';
            }

            const decimal_value: f32 = @floatFromInt(decimal_value_i);
            const div: f32 = @floatFromInt(index-point_index);
            const value_f: f32 = @floatFromInt(value);
            const decimal_float: f32 = (decimal_value / std.math.pow(f32, 10, div-1)) + value_f;

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
};
