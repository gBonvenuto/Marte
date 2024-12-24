const std = @import("std");
const hashmap = @import("./hashmap.zig");
const Lex = @import("./LexicalAnalyzer.zig").Lex;

const stdin = std.io.getStdIn().reader();
const stdout = std.io.getStdOut().writer();
var variablesHashMap: ?hashmap.VariablesHashMap = null;

fn get_filename(args: [][]u8) ![]const u8 {
    if (args.len < 2) {
        return error.FileFieldEmpty;
    }

    const file_name: []const u8 = args[1];
    return file_name;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const file_name: ?[]const u8 = get_filename(args) catch |err| switch (err) {
        error.FileFieldEmpty => null,
        else => return err,
    };

    if (file_name) |f| {
        variablesHashMap = try hashmap.VariablesHashMap.init(allocator);
        // Abrindo o arquivo
        var file = std.fs.cwd().openFile(f, .{ .mode = .read_only }) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("File Not found!", .{});
                return;
            },
            else => return err,
        };
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        // Deixando o conteúdo imutável (boas práticas)
        const file_content: []const u8 = content;

        tokenizer(file_content, allocator) catch |err| switch (err) {
            else => return err,
        };
    } else {
        try interactive(allocator);
    }
}

fn interactive(allocator: std.mem.Allocator) !void {
    try stdout.print("Marte 0.0.1 Copyright (C) 2024 Giancarlo Bonvenuto\n", .{});

    while (true) {
        try stdout.print("> ", .{});
        var line: [1000]u8 = undefined;
        _ = try stdin.readUntilDelimiter(&line, '\n');
        try tokenizer(&line, allocator);
    }
}

// Tokens reconhecidos

pub fn tokenizer(content: []const u8, allocator: std.mem.Allocator) !void {

    // Iterando pelas palavras

    // var varName: []const u8 = undefined;
    // var evVar: bool = false;

    var i: usize = 0;
    while (i < content.len) : (i += 1) {
        const char = content[i];
        if (char >= '0' and char <= '9') {
            const ret = try Lex.numbers(content, i, allocator);
            const token = ret.token;
            i = ret.index;
            const value: *f32 = @alignCast(@ptrCast(token.value));
            std.debug.print("token: {any}, value: {any}\n", .{ token, value.* });
        }

        // switch (char) {
        // }

        // // Iterando pelo Enum de tokens
        // var word: []u8 = @constCast(&[_]u8{0} ** 100);
        // word[0] = char;
        // inline for (1..100) |j| {
        //     if (std.ascii.isWhitespace(content[i + j])) {
        //         word[j] = 0;
        //         break;
        //     }
        //
        //     word[j] = content[i + j];
        // }
        // inline for (@typeInfo(Tokens).Enum.fields) |token| {
        //     if (std.mem.eql(u8, token.name, word)) {
        //         std.debug.print("{s} == {s}\n", .{ word, token.name });
        //         break;
        //     }
        // }
    }
}

fn handleVars(word: []const u8) !void {
    const int: u8 = 8;
    _ = try variablesHashMap.?.assignVar(word, @ptrCast(@constCast(&int)));
}
