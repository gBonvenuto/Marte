const std = @import("std");

const stdin = std.io.getStdIn().reader();

fn get_filename(args: [][]u8) ![]const u8 {
    if (args.len < 2) {
        return error.FileFieldEmpty;
    }

    const file_name: []const u8 = args[1];
    return file_name;
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    const file_name: []const u8 = get_filename(args) catch |err| switch (err) {
        error.FileFieldEmpty => {
            std.debug.print("No file provided. Use {s} <File_Name>\n", .{args[0]});
            return;
        },
        else => return err,
    };

    tokenizer(file_name) catch |err| switch (err) {
        error.UnknownToken => return,
        else => return err,
    };
}

// Tokens reconhecidos
const Tokens = enum {
    @"if",
    then,
    @"else",
};

pub fn tokenizer(file_name: []const u8) !void {
    // Abrindo o arquivo
    var file = std.fs.cwd().openFile(file_name, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File Not found!", .{});
            return;
        },
        else => return err,
    };
    defer file.close();

    const allocator = std.heap.page_allocator;
    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    // Deixando o conteúdo imutável (boas práticas)
    const file_content: []const u8 = content;

    // Iterando pelas palavras
    var iter = std.mem.tokenize(u8, file_content, " \n\t");
    outer: while (iter.next()) |word| {
        // Iterando pelo Enum de tokens
        inline for (@typeInfo(Tokens).Enum.fields) |token| {
            if (std.mem.eql(u8, token.name, word)) {
                std.debug.print("{s} == {s}\n", .{ word, token.name });
                continue :outer;
            }
        }
        std.debug.print("Unknown Token: {s}\n", .{word});
        return error.UnknownToken;
    }
}
