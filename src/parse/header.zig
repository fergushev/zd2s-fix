const is_test = @import("builtin").is_test;
const main = @import("../main.zig");

const verifyIdentifier = main.helper.verifyIdentifier;

const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const header_log = std.log.scoped(.Header);

const Parser = main.d2parser.D2SParser;
const StartOffset = main.d2parser.StartOffset;

var header_test_buffer = [_]u8{
    0x55, 0xAA, 0x55, 0xAA,
    0x60, 0x00, 0x00, 0x00,
    0x68, 0x15, 0x00, 0x00,
    0x62, 0x6A, 0x85, 0xA4,
};

/// Size: 128
pub fn readHeader(parser: *Parser) !void {
    if (parser.offset != @intFromEnum(StartOffset.header) and !is_test) {
        return error.BadStartingOffset;
    }

    var header = &parser.charsave.header;
    header.identifier = try parser.readBits(u32, 32);
    try verifyIdentifier(header.identifier, .save);

    header.version = try parser.readBits(u32, 32);
    header.size = try parser.readBits(u32, 32);
    if (header.size != parser.buffer.len and !is_test) {
        return error.BadHeaderSize;
    }

    header.checksum = try parser.readBits(u32, 32);
    if (main.log_header) {
        header_log.debug("Version: {d}, Size: 0x{x}, Checksum: 0x{x}", .{ header.version, header.size, header.checksum });
    }
}

test "header: read good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.buffer = &header_test_buffer;
    try readHeader(&parser);

    try expectEqual(0xaa55aa55, parser.charsave.header.identifier);
    try expectEqual(96, parser.charsave.header.version);
    try expectEqual(0x1568, parser.charsave.header.size);
    try expectEqual(0xa4856a62, parser.charsave.header.checksum);
}

pub fn writeHeader(parser: *Parser) void {
    const header = &parser.charsave.header;
    parser.writeBits(32, header.identifier);
    parser.writeBits(32, header.version);
    parser.writeBits(32, header.size);
    parser.writeBits(32, header.checksum);
}

test "header: write good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = try Parser.testInit(allocator);

    parser.charsave.header.identifier = 0xaa55aa55;
    parser.charsave.header.version = 96;
    parser.charsave.header.size = 0x1568;
    parser.charsave.header.checksum = 0xa4856a62;

    writeHeader(&parser);

    for (header_test_buffer, 0..) |test_byte, i| {
        try expectEqual(test_byte, parser.out_buffer[i]);
    }
}

pub fn updateHeader(parser: *Parser) !u32 {
    const size: u32 = @as(u32, @intCast(parser.out_offset)) / 8;
    const out_end = parser.out_offset;

    parser.out_offset = 64;
    parser.writeBits(32, size);

    const checksum = try main.helper.calcChecksum(parser.out_buffer[0..size], size);
    parser.writeBits(32, checksum);
    parser.out_offset = out_end;

    return checksum;
}
