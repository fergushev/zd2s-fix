const main = @import("main.zig");

const std = @import("std");
const Dir = std.fs.Dir;
const print = std.debug.print;
const assert = std.debug.assert;

const char_save = main.charsave;
const CharacterSave = char_save.CharacterSave;

const d2txt = main.d2txt;
const TxtFileSizes = d2txt.TxtFileSizes;
const ItemStatCostTxt = d2txt.ItemStatCostTxt;
const WamTxt = d2txt.WamTxt;
const ItemTypesTxt = d2txt.ItemTypesTxt;

const helper = main.helper;
const findAllEquivalentTypes = helper.findAllEquivalentTypes;

// TODO: remove these 2 and cleanup test init
pub fn createItemTypeMap(allocator: std.mem.Allocator, itypes_array: *std.ArrayList(ItemTypesTxt)) !std.StringHashMap(ItemTypesTxt) {
    var item_type_map = std.StringHashMap(ItemTypesTxt).init(allocator);

    var equiv1_map = std.StringHashMap([]u8).init(allocator);
    var equiv2_map = std.StringHashMap([]u8).init(allocator);
    defer equiv1_map.deinit();
    defer equiv2_map.deinit();

    for (itypes_array.items) |*itype| {
        if (!std.mem.eql(u8, @as([]u8, itype.equiv1.items), "")) {
            try equiv1_map.put(@as([]u8, itype.code.items), @as([]u8, itype.equiv1.items));
        }

        if (!std.mem.eql(u8, @as([]u8, itype.equiv2.items), "")) {
            try equiv2_map.put(@as([]u8, itype.code.items), @as([]u8, itype.equiv2.items));
        }
    }

    for (itypes_array.items) |*itype| {
        const item_code: []u8 = @as([]u8, itype.code.items);

        if (!std.mem.eql(u8, item_code, "")) {
            try findAllEquivalentTypes(item_code, &itype.equiv_types, &equiv1_map, &equiv2_map);
            try item_type_map.put(item_code, itype.*);
        }
    }

    return item_type_map;
}

pub fn createItemCodeMap(allocator: std.mem.Allocator, wam_list: *std.ArrayList(WamTxt)) !std.StringHashMap(WamTxt) {
    var item_code_map = std.StringHashMap(WamTxt).init(allocator);

    for (wam_list.items) |*wam| {
        try item_code_map.put(@as([]u8, wam.code.items), wam.*);
    }

    return item_code_map;
}

pub const StartOffset = enum(u32) {
    header = 0,
    char_data = 128,
    hotkeys = 448,
    mouse_skills = 960,
    equipment = 1088,
    map_info = 1344,
    mercenary = 1400,
    guild = 1528,
    quest = 2680,
    waypoint = 5064,
    npc_intro = 5704,
    char_stats = 6120,
};

pub const ItemOffsetDetails = struct {
    start_offset: usize,
    length: usize,
    end_offset: usize,
};

const ItemSaveDetails = struct {
    const Self = @This();

    player_items: i16,
    corpse_items: i16,
    merc_items: i16,
    golem_items: i16,
    stash_items: i16,

    player_start: usize,
    corpse_start: usize,
    merc_start: usize,
    golem_start: usize,

    player_size: std.ArrayList(ItemOffsetDetails),
    corpse_size: std.ArrayList(ItemOffsetDetails),
    merc_size: std.ArrayList(ItemOffsetDetails),
    golem_size: std.ArrayList(ItemOffsetDetails),
    stash_size: std.ArrayList(ItemOffsetDetails),

    current_index: usize,
    current_limit: usize,
    removed_items: u32,

    pub fn init(_: Self, allocator: std.mem.Allocator) Self {
        return Self{
            .player_items = 0,
            .corpse_items = 0,
            .merc_items = 0,
            .golem_items = 0,
            .stash_items = 0,

            .player_start = 0,
            .corpse_start = 0,
            .merc_start = 0,
            .golem_start = 0,

            .player_size = std.ArrayList(ItemOffsetDetails).init(allocator),
            .corpse_size = std.ArrayList(ItemOffsetDetails).init(allocator),
            .merc_size = std.ArrayList(ItemOffsetDetails).init(allocator),
            .golem_size = std.ArrayList(ItemOffsetDetails).init(allocator),
            .stash_size = std.ArrayList(ItemOffsetDetails).init(allocator),

            .current_index = 0,
            .current_limit = 0,
            .removed_items = 0,
        };
    }
};

pub const D2SParser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    buffer: []u8,
    out_buffer: []u8,
    offset: usize,
    out_offset: usize,

    item_details: *ItemSaveDetails,
    charsave: *CharacterSave,

    isc_list: *std.ArrayList(ItemStatCostTxt),
    wam_list: *std.ArrayList(WamTxt),
    itypes_list: *std.ArrayList(ItemTypesTxt),

    item_code_map: *std.StringHashMap(WamTxt),
    item_type_map: *std.StringHashMap(ItemTypesTxt),

    pub fn init(
        allocator: std.mem.Allocator,
        buffer: []u8,
        out_buffer: []u8,
        isc_list: *std.ArrayList(ItemStatCostTxt),
        wam_list: *std.ArrayList(WamTxt),
        itypes_list: *std.ArrayList(ItemTypesTxt),
        item_code_map: *std.StringHashMap(WamTxt),
        item_type_map: *std.StringHashMap(ItemTypesTxt),
    ) !Self {
        const item_details: *ItemSaveDetails = try allocator.create(ItemSaveDetails);
        item_details.* = item_details.*.init(allocator);
        const charsave: *CharacterSave = try allocator.create(CharacterSave);

        charsave.stats.char_statlist = try allocator.create(std.AutoArrayHashMap(u32, u32));
        charsave.stats.char_statlist.* = std.AutoArrayHashMap(u32, u32).init(allocator);

        return Self{
            .allocator = allocator,
            .buffer = buffer,
            .out_buffer = out_buffer,
            .offset = 0,
            .out_offset = 0,

            .item_details = item_details,
            .charsave = charsave,

            .isc_list = isc_list,
            .wam_list = wam_list,
            .itypes_list = itypes_list,

            .item_code_map = item_code_map,
            .item_type_map = item_type_map,
        };
    }

    pub fn testInit(allocator: std.mem.Allocator) !Self {
        const out_buffer: []u8 = try allocator.alloc(u8, 16 * 1000);
        const file_sizes: *TxtFileSizes = try d2txt.getFileSizes(allocator);
        const charsave = try allocator.create(CharacterSave);
        charsave.stats.char_statlist = try allocator.create(std.AutoArrayHashMap(u32, u32));
        charsave.stats.char_statlist.* = std.AutoArrayHashMap(u32, u32).init(allocator);

        const isc_list = try d2txt.getItemStatCostTxt(allocator);
        var wam_list = try d2txt.getWamTxt(allocator);
        var itypes_list = try d2txt.getItemTypesTxt(allocator);

        const item_code_map = try createItemCodeMap(allocator, &wam_list);
        const item_type_map = try createItemTypeMap(allocator, &itypes_list);

        return Self{
            .allocator = allocator,
            .buffer = undefined,
            .out_buffer = out_buffer,
            .offset = 0,
            .out_offset = 0,

            .file_sizes = file_sizes,
            .charsave = charsave,

            .isc_list = isc_list,
            .wam_list = wam_list,
            .itypes_list = itypes_list,

            .item_code_map = item_code_map,
            .item_type_map = item_type_map,
        };
    }

    pub fn deinit(self: *Self) void {
        self.item_type_map.deinit();
        self.item_code_map.deinit();

        if (self.charsave.extra.has_extra) {
            self.allocator.free(self.charsave.extra.buffer);
        }
        self.allocator.free(self.buffer);
        self.allocator.free(self.out_buffer);
        self.allocator.destroy(self.file_sizes);

        if (self.charsave.items.item_list_header.item_count > 0) {
            for (self.charsave.items.item) |*item| {
                if (item.sockets > 0) {
                    self.allocator.free(item.socketed_items);
                }
            }
            self.allocator.free(self.charsave.items.item);
        }
        if (self.charsave.corpse.item_list_header.item_count > 0) {
            for (self.charsave.corpse.item) |*item| {
                if (item.sockets > 0) {
                    self.allocator.free(item.socketed_items);
                }
            }
            self.allocator.free(self.charsave.corpse.item);
        }
        if (self.charsave.merc_items.item_list_header.item_count > 0) {
            for (self.charsave.merc_items.item) |*item| {
                if (item.sockets > 0) {
                    self.allocator.free(item.socketed_items);
                }
            }
            self.allocator.free(self.charsave.merc_items.item);
        }
        if (self.charsave.golem.has_golem == 1) {
            for (self.charsave.golem.item) |*item| {
                if (item.sockets > 0) {
                    self.allocator.free(item.socketed_items);
                }
            }
            self.allocator.free(self.charsave.golem.item);
        }

        self.charsave.stats.char_statlist.*.deinit();
        self.allocator.destroy(self.charsave.stats.char_statlist);
        self.allocator.destroy(self.charsave);

        for (self.itypes_list.items) |*u| {
            u.deinit();
        }
        self.itypes_list.deinit();

        for (self.isc_list.items) |*u| {
            u.deinit();
        }
        self.isc_list.deinit();

        for (self.wam_list.items) |*u| {
            u.deinit();
        }
        self.wam_list.deinit();
    }

    pub fn testDeinit(self: *Self, free_items: bool) void {
        self.item_type_map.deinit();
        self.item_code_map.deinit();

        // if (free_items) {
        //     self.allocator.free(self.charsave.items.item);
        // }
        if (free_items and self.charsave.items.item_list_header.item_count > 0) {
            for (self.charsave.items.item) |*item| {
                if (item.sockets > 0) {
                    self.allocator.free(item.socketed_items);
                }
            }
            self.allocator.free(self.charsave.items.item);
        }

        // if (self.charsave.extra.has_extra) {
        //     self.allocator.free(self.charsave.extra);
        // }

        if (self.charsave.corpse.item_list_header.item_count > 0) {
            for (self.charsave.corpse.item) |*item| {
                if (item.sockets > 0) {
                    self.allocator.free(item.socketed_items);
                }
            }
            self.allocator.free(self.charsave.corpse.item);
        }
        if (self.charsave.merc_items.item_list_header.item_count > 0) {
            for (self.charsave.merc_items.item) |*item| {
                if (item.sockets > 0) {
                    self.allocator.free(item.socketed_items);
                }
            }
            self.allocator.free(self.charsave.merc_items.item);
        }
        if (self.charsave.golem.has_golem == 1) {
            for (self.charsave.golem.item) |*item| {
                if (item.sockets > 0) {
                    self.allocator.free(item.socketed_items);
                }
            }
            self.allocator.free(self.charsave.golem.item);
        }

        self.allocator.free(self.out_buffer);
        self.allocator.destroy(self.file_sizes);
        self.charsave.stats.char_statlist.*.deinit();
        self.allocator.destroy(self.charsave.stats.char_statlist);
        self.allocator.destroy(self.charsave);

        for (self.itypes_list.items) |*u| {
            u.deinit();
        }
        self.itypes_list.deinit();

        for (self.isc_list.items) |*u| {
            u.deinit();
        }
        self.isc_list.deinit();

        for (self.wam_list.items) |*u| {
            u.deinit();
        }
        self.wam_list.deinit();
    }

    pub fn readBits(self: *Self, comptime T: type, bit_count: usize) !T {
        if (self.item_details.current_limit != 0 and self.offset >= self.item_details.current_limit) {
            // print("LIMIT: {x} | \n", .{self.item_details.current_limit / 8});
            return error.InvalidItemLength;
        }

        const output: T = std.mem.readVarPackedInt(T, self.buffer, self.offset, bit_count, .little, .unsigned);
        self.offset += bit_count;
        return output;
    }

    pub fn readByteArray(self: *Self, input: []u8) !void {
        for (0..input.len) |i| {
            if (self.item_details.current_limit != 0 and self.offset >= self.item_details.current_limit) {
                // print("LIMIT []: {x} | \n", .{self.item_details.current_limit / 8});
                return error.InvalidItemLength;
            }

            input[i] = std.mem.readPackedInt(u8, self.buffer, self.offset, .little);
            self.offset += 8;
        }
    }

    pub fn writeBits(self: *Self, bit_count: usize, value: anytype) void {
        std.mem.writeVarPackedInt(self.out_buffer, self.out_offset, bit_count, value, .little);
        self.out_offset += bit_count;
    }

    pub fn writeByteArray(self: *Self, input: []u8) void {
        for (0..input.len) |i| {
            std.mem.writePackedInt(u8, self.out_buffer, self.out_offset, input[i], .little);
            self.out_offset += 8;
        }
    }

    pub fn alignToByte(self: *Self) void {
        const offset_diff = self.offset % 8;

        if (offset_diff != 0) {
            self.offset += 8 - offset_diff;
        }
    }

    pub fn padToByte(self: *Self) void {
        const offset_diff = self.out_offset % 8;

        if (offset_diff != 0) {
            self.writeBits(8 - offset_diff, @as(u32, 0));
        }
    }
};
