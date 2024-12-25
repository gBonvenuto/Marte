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
        var buf: [1000]u8 = undefined;
        const line = try stdin.readUntilDelimiter(&buf, '\n');
        try tokenizer(line, allocator);
    }
}

// Tokens reconhecidos

pub fn tokenizer(content: []const u8, allocator: std.mem.Allocator) !void {
    var i: usize = 0;

    while (i < content.len) : (i += 1) {

        // Imprimir os tokens
        var token: ?Lex.Token = null;
        defer {
            if (token) |t|
                t.print() catch {};
        }

        const char = content[i];

        // Se for o caracter nulo, terminar
        if (char == 0) {
            break;
        }

        // Se for whitespace a gente ignora
        if (std.ascii.isWhitespace(char)) {
            continue;
        }

        // Se for um número, aplicamos um parser próprio
        if (char >= '0' and char <= '9') {
            const ret = try Lex.numbers(content, i, allocator);
            i = ret.index;
            token = ret.token;
            continue;
        }

        // Se for um caracter de operador, tratamos aqui
        switch (char) {
            '+', '-', '*', '/', '=' => {
                token = try Lex.operators(content, i, allocator);
            },
            else => std.debug.print("char: {d}", .{char}),
        }
    }
}

fn handleVars(word: []const u8) !void {
    const int: u8 = 8;
    _ = try variablesHashMap.?.assignVar(word, @ptrCast(@constCast(&int)));
}
