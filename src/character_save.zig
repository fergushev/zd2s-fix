const std = @import("std");
const isc = @import("itemstat.zig");

const d2txt = @import("d2txt.zig");
const ItemStatCostTxt = d2txt.ItemStatCostTxt;

pub const CharacterSave = struct {
    header: SaveHeader,
    character_data: CharacterData,
    hotkeys: [16]Hotkeys,
    mouse_skills: MouseSkills,
    equipment: EquipDetails,
    town: [3]Town,
    map_seed: u32,
    mercenary: Mercenary,
    unknown_191: [144]u8,

    quest_data: QuestData,
    waypoint_data: WaypointData,
    npc_data: NPCIntro,
    stats: CharacterStats,
    skills: CharacterSkills,
    items: CharacterItems,
    corpse: CorpseItems,
    merc_items: MercenaryItems,
    golem: GolemItems,

    stash: StashItems,
    extra: Extra, // used to store any (custom) extra data at the end of the save file
};

pub const SaveHeader = struct {
    identifier: u32 = @intFromEnum(SaveIdentifiers.save),
    version: u32,
    size: u32,
    checksum: u32,
};

pub const SaveIdentifiers = enum(u32) {
    save = 0xAA55AA55,
    quest = 0x216f6f57, // Woo!
    waypoint = 0x5357, // WS
    npc = 0x7701,
    stats = 0x6667, // gf
    skills = 0x6669, // if
    items = 0x4D4A, // JM
    merc = 0x666A, // jf
    golem = 0x666B, // kf
    guild = 0x029a029a,
};

pub const CharacterData = struct {
    weapon_swap: u32,
    name: [16]u8,
    save_flags: SaveFlags,
    class: CharacterClass,
    stats: u8,
    skills: u8, // 30 by default
    level: u8,
    create_time: u32,
    last_played: u32,
    play_time: u32,
};

pub const SaveFlags = packed struct(u32) {
    init: bool,
    _0x02: bool,
    hardcore: bool,
    dead: bool,
    _0x10: bool,
    expansion: bool,
    ladder: bool,
    _0x80: bool,
    quest_data: u5,
    weapon_switch: bool,
    _unused: u18,
};

const CharacterClass = enum(u8) {
    amazon = 0,
    sorceress,
    necromancer,
    paladin,
    barbarian,
    druid,
    assassin,
};

pub const Hotkeys = struct {
    skill: u16,
    item: u16,
};

pub const MouseSkills = struct {
    left: SelectedSkill,
    right: SelectedSkill,
    left_swap: SelectedSkill,
    right_swap: SelectedSkill,
};

pub const SelectedSkill = struct {
    skill_id: u16,
    item_index: u16,
};

pub const EquipDetails = struct {
    component: Equipment,
    color: Equipment,
};

const Equipment = struct {
    head: u8,
    torso: u8,
    legs: u8,
    right_arm: u8,
    left_arm: u8,
    right_hand: u8,
    left_hand: u8,
    shield: u8,

    special_1: u8,
    special_2: u8,
    special_3: u8,
    special_4: u8,
    special_5: u8,
    special_6: u8,
    special_7: u8,
    special_8: u8,
};

const Town = packed struct(u8) {
    act: u7,
    active: bool,
};

const UnitFlags = packed struct(u32) {
    _first: u16,
    is_dead: bool,
    _last: u12,
    _unused: u3,
};

pub const Mercenary = struct {
    flags: UnitFlags,
    seed: u32,
    name_id: u16,
    merc_id: u16,
    experience: u32,
};

const QuestFlags = packed struct(u16) {
    reward_granted: bool,
    reward_pending: bool,
    started: bool,
    leave_town: bool,
    enter_area: bool,
    custom1: bool,
    custom2: bool,
    custom3: bool,
    custom4: bool,
    custom5: bool,
    custom6: bool,
    custom7: bool,
    update_log: bool,
    primary_goal: bool,
    completed_now: bool,
    completed_before: bool,
};

pub const QuestData = struct {
    identifier: u32,
    version: u32,
    size: u16, // 298
    quests: [3]Quest,
};

const Quest = packed struct(u768) {
    act1: Act1Quest,
    act2: Act2Quest,
    act3: Act3Quest,
    act4: Act4Quest,

    flavie: QuestFlags, // A1Q7 - no flags are set
    guard_1: QuestFlags, // A2Q7 - unused
    guard_2: QuestFlags, // A2Q8 - unused
    dark_wanderer: QuestFlags, // A3Q7 - reward_granted set after minions spawn
    hadriel: QuestFlags, // A4Q4 - no flags are set

    act5: Act5Quest,

    akara_respec: QuestFlags, // 1.13c+
    _unused: u96,
};

pub const Act1Quest = packed struct(u128) {
    intro: QuestFlags,
    den_of_evil: QuestFlags,
    burial_grounds: QuestFlags,
    tools_of_the_trade: QuestFlags,
    search_for_cain: QuestFlags,
    forgotten_tower: QuestFlags,
    sister_to_the_slaughter: QuestFlags,
    complete: QuestFlags,
};

pub const Act2Quest = packed struct(u128) {
    intro: QuestFlags,
    radaments_lair: QuestFlags,
    horadric_staff: QuestFlags,
    tainted_sun: QuestFlags,
    arcane_sanctuary: QuestFlags,
    the_summoner: QuestFlags,
    seven_tombs: QuestFlags,
    complete: QuestFlags,
};

pub const Act3Quest = packed struct(u128) {
    intro: QuestFlags,
    lam_esens_tome: QuestFlags,
    khalims_will: QuestFlags,
    blade_of_old_religion: QuestFlags,
    golden_bird: QuestFlags,
    blackened_temple: QuestFlags,
    the_guardian: QuestFlags,
    complete: QuestFlags,
};

pub const Act4Quest = packed struct(u80) {
    intro: QuestFlags,
    fallen_angel: QuestFlags,
    terrors_end: QuestFlags,
    hell_forge: QuestFlags,
    complete: QuestFlags,
};

pub const Act5Quest = packed struct(u112) {
    intro: QuestFlags,
    siege_on_harrogath: QuestFlags,
    rescue_on_mount_arreat: QuestFlags,
    prison_of_ice: QuestFlags,
    betrayal_of_harrogath: QuestFlags,
    rite_of_passage: QuestFlags,
    eve_of_destruction: QuestFlags,
};

pub const WaypointData = struct {
    identifier: u16,
    unknown_635: u32,
    size: u16,
    waypoints: [3]Waypoint,
};

const Waypoint = packed struct(u192) {
    version: u16,
    act1: Act1Waypoint,
    act2: Act2Waypoint,
    act3: Act3Waypoint,
    act4: Act4Waypoint,
    act5: Act5Waypoint,
    _unused: u73,
    unknown_1: u32,
    unknown_2: u32,
};

const Act1Waypoint = packed struct(u9) {
    rogue_encampment: bool,
    cold_plains: bool,
    stony_field: bool,
    dark_wood: bool,
    black_marsh: bool,
    outer_cloister: bool,
    jail_1: bool,
    inner_cloister: bool,
    catacombs_2: bool,
};

const Act2Waypoint = packed struct(u9) {
    lut_gholein: bool,
    sewers_2: bool,
    dry_hills: bool,
    halls_of_the_dead_2: bool,
    far_oasis: bool,
    lost_city: bool,
    palace_cellar_1: bool,
    arcane_sanctuary: bool,
    canyon_of_the_magi: bool,
};

const Act3Waypoint = packed struct(u9) {
    kurast_docks: bool,
    spider_forest: bool,
    great_marsh: bool,
    flayer_jungle: bool,
    lower_kurast: bool,
    kurast_bazaar: bool,
    upper_kuuast: bool,
    travincal: bool,
    durance_of_hate_2: bool,
};

const Act4Waypoint = packed struct(u3) {
    pandemonium_fortress: bool,
    city_of_the_damned: bool,
    river_of_flame: bool,
};

const Act5Waypoint = packed struct(u9) {
    harrogath: bool,
    frigid_highlands: bool,
    arrest_plateau: bool,
    crystalline_passage: bool,
    glacial_trail: bool,
    halls_of_pain: bool,
    frozen_tundra: bool,
    ancients_way: bool,
    worldstone_keep_2: bool,
};

pub const NPCIntro = struct {
    identifier: u16,
    size: u16, // 52
    quest_intro: [3]NPCDialog,
    npc_intro: [3]NPCDialog,
};

const NPCDialog = packed struct(u64) {
    invalid: u1,

    // Act 1
    gheed: u1,
    akara: u1,
    kashya: u1,
    warriv1: u1,
    charsi: u1,
    cain5: u1,
    warriv2: u1,

    // Act 2
    atma: u1,
    drognan: u1,
    fara: u1,
    lysander: u1,
    geglash: u1,
    meshif1: u1,
    jerhyn: u1,
    greiz: u1,

    // Act 3
    elzix: u1,
    cain2: u1,
    cain3: u1,
    cain4: u1,
    tyrael1: u1,
    asheara: u1,
    hratli: u1,
    alkor: u1,
    ormus: u1,

    // Act 4
    izual: u1,
    halbu: u1,
    meshif2: u1,

    // Act 5
    natalya: u1,
    larzuk: u1,
    anya: u1,
    malah: u1,
    nihlathak: u1,
    qual_kehk: u1,
    cain6: u1,

    _unused: u29,
};

pub const CharacterStats = struct {
    identifier: u16,
    char_statlist: *std.AutoArrayHashMap(u32, u32),
};

pub const CharacterSkills = struct {
    identifier: u16,
    skills: [33]u8, // [33] LoD only has 30. TODO: should parse this from the skills file
};

const ItemListHeader = struct {
    identifier: u16, // JM
    item_count: u16,
};

pub const CharacterItems = struct {
    item_list_header: ItemListHeader,
    item: []BasicItem,
};

pub const CorpseItems = struct {
    identifier: u16, // JM
    has_corpse: u16,
    unknown: u32,
    corpseX: u32,
    corpseY: u32,

    item_list_header: ItemListHeader,
    item: []BasicItem,
};

pub const MercenaryItems = struct {
    identifier: u16, // jf
    item_list_header: ItemListHeader,
    item: []BasicItem,
};

pub const GolemItems = struct {
    identifier: u16, // kf
    has_golem: u16,
    item: []BasicItem,
};

pub const StashItems = struct {
    item_list_header: ItemListHeader,
    item: []BasicItem,
};

const ItemFlags = packed struct(u32) {
    new_item: bool,
    target: bool,
    targeting: bool,
    deleted: bool,
    identified: bool,
    quantity: bool,
    switch_in: bool,
    switch_out: bool,

    broken: bool,
    repaired: bool,
    unknown1: bool,
    socketed: bool,
    no_sell: bool,
    in_store: bool,
    no_equip: bool,
    named: bool,

    ear: bool,
    starter: bool,
    unknown2: bool,
    init: bool,
    unknown3: bool,
    compact: bool,
    ethereal: bool,
    just_saved: bool,

    personalized: bool,
    inferior: bool,
    runeword: bool,
    item: bool,

    _unused: u4,
};

pub const ItemModes = enum(u8) {
    stored,
    equipped,
    belt,
    ground,
    cursor,
    dropping,
    socketed,
};

pub const BodyLocation = enum(u8) {
    unequipped,
    head,
    neck,
    torso,
    right_hand,
    left_hand,
    right_ring,
    left_ring,
    waist,
    feet,
    hands,
    right_hand_swap,
    left_hand_swap,
};

pub const InventoryPage = enum(u8) {
    inventory = 0,
    equip,
    trade,
    cube,
    stash,
    stash_page,
    null = 255, // equipped items, socketed items, belt pots
};

pub const BasicItem = struct {
    identifier: u16,
    flags: ItemFlags,
    format: u16,
    animation_mode: ItemModes,
    equipped: BodyLocation,
    unit_x: u16,
    unit_y: u16,
    inv_page: InventoryPage,

    ear_class: CharacterClass,
    ear_level: u8,
    name: [16]u8,

    code: [4]u8,
    realm_data: [3]u32,
    sockets: u8, // filled sockets
    max_sockets: u32,
    seed: u32,
    ilvl: u8,
    quality: ItemQualities,
    custom_gfx: u8,
    automagic: u16,
    file_index: u32,
    set_mask: u32,

    magic_prefix: [3]u32,
    magic_suffix: [3]u32,
    rare_prefix: u8,
    rare_suffix: u8,

    defense: u32,
    durability: u32,
    max_durability: u32,
    quantity: u32,
    quest: u32,

    socketed_items: []BasicItem,
    parent_item: ?*BasicItem,
    is_socket: bool,
    bad_socket: bool,
    sock_index: u8,
    total_statlists: u8,
    statlist: []std.ArrayList(CharStatList),

    index: u16,
    item_source: ItemSource,
    section_end_offset: usize,
    max_index: u16,
};

pub const ItemSource = enum {
    player,
    corpse,
    mercenary,
    golem,
    stash,
};

pub const CharStatList = struct {
    id: u32,
    value: u32,
    param: u32,
};

pub const ItemQualities = enum(u8) {
    invalid = 0,
    inferior = 1,
    normal,
    superior,
    magic,
    set,
    rare,
    unique,
    crafted,
    tempered,
};

pub const max_mods: u8 = 3;

pub const Extra = struct {
    has_extra: bool,
    buffer: []u8,
};

const StartOffset = enum(u32) {
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
