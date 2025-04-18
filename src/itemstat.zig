// If the game code has been rewritten, this value may need to be adjusted
pub const max_item_stat: u9 = 511;

pub const ItemStats = enum(u32) {
    strength = 0,
    energy = 1,
    dexterity = 2,
    vitality = 3,
    statpts = 4,
    newskills = 5,
    hitpoints = 6,
    maxhp = 7,
    mana = 8,
    maxmana = 9,
    stamina = 10,
    maxstamina = 11,
    level = 12,
    experience = 13,
    gold = 14,
    goldbank = 15,
    item_armor_percent = 16,
    item_maxdamage_percent = 17,
    item_mindamage_percent = 18,
    tohit = 19,
    toblock = 20,
    mindamage = 21,
    maxdamage = 22,
    secondary_mindamage = 23,
    secondary_maxdamage = 24,
    damagepercent = 25,
    manarecovery = 26,
    manarecoverybonus = 27,
    staminarecoverybonus = 28,
    lastexp = 29,
    nextexp = 30,
    armorclass = 31,
    armorclass_vs_missile = 32,
    armorclass_vs_hth = 33,
    normal_damage_reduction = 34,
    magic_damage_reduction = 35,
    damageresist = 36,
    magicresist = 37,
    maxmagicresist = 38,
    fireresist = 39,
    maxfireresist = 40,
    lightresist = 41,
    maxlightresist = 42,
    coldresist = 43,
    maxcoldresist = 44,
    poisonresist = 45,
    maxpoisonresist = 46,
    damageaura = 47,
    firemindam = 48,
    firemaxdam = 49,
    lightmindam = 50,
    lightmaxdam = 51,
    magicmindam = 52,
    magicmaxdam = 53,
    coldmindam = 54,
    coldmaxdam = 55,
    coldlength = 56,
    poisonmindam = 57,
    poisonmaxdam = 58,
    poisonlength = 59,
    lifedrainmindam = 60,
    lifedrainmaxdam = 61,
    manadrainmindam = 62,
    manadrainmaxdam = 63,
    stamdrainmindam = 64,
    stamdrainmaxdam = 65,
    stunlength = 66,
    velocitypercent = 67,
    attackrate = 68,
    other_animrate = 69,
    quantity = 70,
    value = 71,
    durability = 72,
    maxdurability = 73,
    hpregen = 74,
    item_maxdurability_percent = 75,
    item_maxhp_percent = 76,
    item_maxmana_percent = 77,
    item_attackertakesdamage = 78,
    item_goldbonus = 79,
    item_magicbonus = 80,
    item_knockback = 81,
    item_timeduration = 82,
    item_addclassskills = 83,
    unsentparam1 = 84,
    item_addexperience = 85,
    item_healafterkill = 86,
    item_reducedprices = 87,
    item_doubleherbduration = 88,
    item_lightradius = 89,
    item_lightcolor = 90,
    item_req_percent = 91,
    item_levelreq = 92,
    item_fasterattackrate = 93,
    item_levelreqpct = 94,
    lastblockframe = 95,
    item_fastermovevelocity = 96,
    item_nonclassskill = 97,
    state = 98,
    item_fastergethitrate = 99,
    monster_playercount = 100,
    skill_poison_override_length = 101,
    item_fasterblockrate = 102,
    skill_bypass_undead = 103,
    skill_bypass_demons = 104,
    item_fastercastrate = 105,
    skill_bypass_beasts = 106,
    item_singleskill = 107,
    item_restinpeace = 108,
    curse_resistance = 109,
    item_poisonlengthresist = 110,
    item_normaldamage = 111,
    item_howl = 112,
    item_stupidity = 113,
    item_damagetomana = 114,
    item_ignoretargetac = 115,
    item_fractionaltargetac = 116,
    item_preventheal = 117,
    item_halffreezeduration = 118,
    item_tohit_percent = 119,
    item_damagetargetac = 120,
    item_demondamage_percent = 121,
    item_undeaddamage_percent = 122,
    item_demon_tohit = 123,
    item_undead_tohit = 124,
    item_throwable = 125,
    item_elemskill = 126,
    item_allskills = 127,
    item_attackertakeslightdamage = 128,
    ironmaiden_level = 129,
    lifetap_level = 130,
    thorns_percent = 131,
    bonearmor = 132,
    bonearmormax = 133,
    item_freeze = 134,
    item_openwounds = 135,
    item_crushingblow = 136,
    item_kickdamage = 137,
    item_manaafterkill = 138,
    item_healafterdemonkill = 139,
    item_extrablood = 140,
    item_deadlystrike = 141,
    item_absorbfire_percent = 142,
    item_absorbfire = 143,
    item_absorblight_percent = 144,
    item_absorblight = 145,
    item_absorbmagic_percent = 146,
    item_absorbmagic = 147,
    item_absorbcold_percent = 148,
    item_absorbcold = 149,
    item_slow = 150,
    item_aura = 151,
    item_indesctructible = 152,
    item_cannotbefrozen = 153,
    item_staminadrainpct = 154,
    item_reanimate = 155,
    item_pierce = 156,
    item_magicarrow = 157,
    item_explosivearrow = 158,
    item_throw_mindamage = 159,
    item_throw_maxdamage = 160,
    skill_handofathena = 161,
    skill_staminapercent = 162,
    skill_passive_staminapercent = 163,
    skill_concentration = 164,
    skill_enchant = 165,
    skill_pierce = 166,
    skill_conviction = 167,
    skill_chillingarmor = 168,
    skill_frenzy = 169,
    skill_decrepify = 170,
    skill_armor_percent = 171,
    alignment = 172,
    target0 = 173,
    target1 = 174,
    goldlost = 175,
    conversion_level = 176,
    conversion_maxhp = 177,
    unit_dooverlay = 178,
    attack_vs_montype = 179,
    damage_vs_montype = 180,
    fade = 181,
    armor_override_percent = 182,
    equipped_eth = 183,
    missing_hp = 184,
    uber_difficulty = 185,
    map_glob_boss_dropskillers = 186,
    map_glob_boss_dropcorruptedunique = 187,
    item_addskill_tab = 188,
    openwounds_stack = 189,
    curse_slots = 190,
    item_skillonequip = 191,
    unused192 = 192,
    unused193 = 193,
    item_numsockets = 194,
    item_skillonattack = 195,
    item_skillonkill = 196,
    item_skillondeath = 197,
    item_skillonhit = 198,
    item_skillonlevelup = 199,
    item_skilloncast = 200,
    item_skillongethit = 201,
    unused202 = 202,
    unused203 = 203,
    item_charged_skill = 204,
    unused204 = 205,
    unused205 = 206,
    unused206 = 207,
    unused207 = 208,
    unused208 = 209,
    unused209 = 210,
    unused210 = 211,
    unused211 = 212,
    item_mindamage_energy = 213,
    item_armor_perlevel = 214,
    item_armorpercent_perlevel = 215,
    item_hp_perlevel = 216,
    item_mana_perlevel = 217,
    item_maxdamage_perlevel = 218,
    item_maxdamage_percent_perlevel = 219,
    item_strength_perlevel = 220,
    item_dexterity_perlevel = 221,
    item_energy_perlevel = 222,
    item_vitality_perlevel = 223,
    item_tohit_perlevel = 224,
    item_tohitpercent_perlevel = 225,
    item_cold_damagemax_perlevel = 226,
    item_fire_damagemax_perlevel = 227,
    item_ltng_damagemax_perlevel = 228,
    item_pois_damagemax_perlevel = 229,
    item_resist_cold_perlevel = 230,
    item_resist_fire_perlevel = 231,
    item_resist_ltng_perlevel = 232,
    item_resist_pois_perlevel = 233,
    item_absorb_cold_perlevel = 234,
    item_absorb_fire_perlevel = 235,
    item_absorb_ltng_perlevel = 236,
    item_absorb_pois_perlevel = 237,
    item_thorns_perlevel = 238,
    item_find_gold_perlevel = 239,
    item_find_magic_perlevel = 240,
    item_regenstamina_perlevel = 241,
    item_stamina_perlevel = 242,
    item_damage_demon_perlevel = 243,
    item_damage_undead_perlevel = 244,
    item_tohit_demon_perlevel = 245,
    item_tohit_undead_perlevel = 246,
    item_crushingblow_perlevel = 247,
    item_openwounds_perlevel = 248,
    item_kick_damage_perlevel = 249,
    item_deadlystrike_perlevel = 250,
    item_find_gems_perlevel = 251,
    item_replenish_durability = 252,
    item_replenish_quantity = 253,
    item_extra_stack = 254,
    item_find_item = 255,
    item_slash_damage = 256,
    item_slash_damage_percent = 257,
    item_crush_damage = 258,
    item_crush_damage_percent = 259,
    item_thrust_damage = 260,
    item_thrust_damage_percent = 261,
    item_absorb_slash = 262,
    item_absorb_crush = 263,
    item_absorb_thrust = 264,
    item_absorb_slash_percent = 265,
    item_absorb_crush_percent = 266,
    item_absorb_thrust_percent = 267,
    item_armor_bytime = 268,
    item_armorpercent_bytime = 269,
    item_hp_bytime = 270,
    item_mana_bytime = 271,
    item_maxdamage_bytime = 272,
    item_maxdamage_percent_bytime = 273,
    item_strength_bytime = 274,
    item_dexterity_bytime = 275,
    item_energy_bytime = 276,
    item_vitality_bytime = 277,
    item_tohit_bytime = 278,
    item_tohitpercent_bytime = 279,
    item_cold_damagemax_bytime = 280,
    item_fire_damagemax_bytime = 281,
    item_ltng_damagemax_bytime = 282,
    item_pois_damagemax_bytime = 283,
    item_resist_cold_bytime = 284,
    item_resist_fire_bytime = 285,
    item_resist_ltng_bytime = 286,
    item_resist_pois_bytime = 287,
    item_absorb_cold_bytime = 288,
    item_absorb_fire_bytime = 289,
    item_absorb_ltng_bytime = 290,
    item_absorb_pois_bytime = 291,
    item_find_gold_bytime = 292,
    item_find_magic_bytime = 293,
    item_regenstamina_bytime = 294,
    item_stamina_bytime = 295,
    item_damage_demon_bytime = 296,
    item_damage_undead_bytime = 297,
    item_tohit_demon_bytime = 298,
    item_tohit_undead_bytime = 299,
    item_crushingblow_bytime = 300,
    item_openwounds_bytime = 301,
    item_kick_damage_bytime = 302,
    item_deadlystrike_bytime = 303,
    item_find_gems_bytime = 304,
    item_pierce_cold = 305,
    item_pierce_fire = 306,
    item_pierce_ltng = 307,
    item_pierce_pois = 308,
    item_damage_vs_monster = 309,
    item_damage_percent_vs_monster = 310,
    item_tohit_vs_monster = 311,
    item_tohit_percent_vs_monster = 312,
    item_ac_vs_monster = 313,
    item_ac_percent_vs_monster = 314,
    firelength = 315,
    burningmin = 316,
    burningmax = 317,
    progressive_damage = 318,
    progressive_steal = 319,
    progressive_other = 320,
    progressive_fire = 321,
    progressive_cold = 322,
    progressive_lightning = 323,
    item_extra_charges = 324,
    progressive_tohit = 325,
    poison_count = 326,
    damage_framerate = 327,
    pierce_idx = 328,
    passive_fire_mastery = 329,
    passive_ltng_mastery = 330,
    passive_cold_mastery = 331,
    passive_pois_mastery = 332,
    passive_fire_pierce = 333,
    passive_ltng_pierce = 334,
    passive_cold_pierce = 335,
    passive_pois_pierce = 336,
    passive_critical_strike = 337,
    passive_dodge = 338,
    passive_avoid = 339,
    passive_evade = 340,
    passive_warmth = 341,
    passive_mastery_melee_th = 342,
    passive_mastery_melee_dmg = 343,
    passive_mastery_melee_crit = 344,
    passive_mastery_throw_th = 345,
    passive_mastery_throw_dmg = 346,
    passive_mastery_throw_crit = 347,
    passive_weaponblock = 348,
    passive_summon_resist = 349,
    modifierlist_skill = 350,
    modifierlist_level = 351,
    last_sent_hp_pct = 352,
    source_unit_type = 353,
    source_unit_id = 354,
    shortparam1 = 355,
    questitemdifficulty = 356,
    passive_mag_mastery = 357,
    passive_mag_pierce = 358,
    item_splashonhit = 359,
    corrupted = 360,
    corruptor = 361,
    item_elemskill_cold = 362,
    item_elemskill_fire = 363,
    item_elemskill_lightning = 364,
    item_elemskill_poison = 365,
    item_elemskill_magic = 366,
    skill_cold_enchant = 367,
    max_curses = 368,
    map_defense = 369,
    map_play_magicbonus = 370,
    map_play_goldbonus = 371,
    map_glob_density = 372,
    map_play_addexperience = 373,
    map_glob_arealevel = 374,
    map_glob_monsterrarity = 375,
    map_mon_firemindam = 376,
    map_mon_firemaxdam = 377,
    map_mon_lightmindam = 378,
    map_mon_lightmaxdam = 379,
    map_mon_magicmindam = 380,
    map_mon_magicmaxdam = 381,
    map_mon_coldmindam = 382,
    map_mon_coldmaxdam = 383,
    map_mon_coldlength = 384,
    map_mon_poisonmindam = 385,
    map_mon_poisonmaxdam = 386,
    map_mon_poisonlength = 387,
    map_mon_passive_fire_mastery = 388,
    map_mon_passive_ltng_mastery = 389,
    map_mon_passive_cold_mastery = 390,
    map_mon_passive_pois_mastery = 391,
    map_mon_fasterattackrate = 392,
    map_mon_fastercastrate = 393,
    map_mon_tohit = 394,
    map_mon_ac_percent = 395,
    map_mon_absorbcold_percent = 396,
    map_mon_absorbmagic_percent = 397,
    map_mon_absorblight_percent = 398,
    map_mon_absorbfire_percent = 399,
    map_mon_normal_damage_reduction = 400,
    map_mon_velocitypercent = 401,
    map_mon_hpregen = 402,
    map_mon_lifedrainmindam = 403,
    map_mon_fastergethitrate = 404,
    map_mon_maxhp_percent = 405,
    map_mon_pierce = 406,
    map_mon_openwounds = 407,
    map_mon_crushingblow = 408,
    map_mon_curse_resistance = 409,
    map_play_ac_percent = 410,
    map_play_fastergethitrate = 411,
    map_play_toblock = 412,
    map_play_hpregen = 413,
    map_mon_passive_fire_pierce = 414,
    map_mon_passive_ltng_pierce = 415,
    map_mon_passive_cold_pierce = 416,
    map_mon_passive_pois_pierce = 417,
    map_play_maxfireresist = 418,
    map_play_maxlightresist = 419,
    map_play_maxcoldresist = 420,
    map_play_maxpoisonresist = 421,
    item_replenish_charges = 422,
    item_leap_speed = 423,
    item_healafterhit = 424,
    passive_phys_pierce = 425,
    map_mon_ed_percent = 426,
    map_mon_splash = 427,
    map_play_fireresist = 428,
    map_play_lightresist = 429,
    map_play_coldresist = 430,
    map_play_poisonresist = 431,
    map_mon_phys_as_extra_ltng = 432,
    map_mon_phys_as_extra_cold = 433,
    map_mon_phys_as_extra_fire = 434,
    map_mon_phys_as_extra_pois = 435,
    map_mon_phys_as_extra_mag = 436,
    map_glob_add_mon_doll = 437,
    map_glob_add_mon_succ = 438,
    map_glob_add_mon_vamp = 439,
    map_glob_add_mon_cow = 440,
    map_glob_add_mon_horde = 441,
    map_glob_add_mon_ghost = 442,
    extra_bonespears = 443,
    extra_revives = 444,
    immune_stat = 445,
    mon_cooldown1 = 446,
    mon_cooldown2 = 447,
    mon_cooldown3 = 448,
    map_mon_deadlystrike = 449,
    map_mon_cannotbefrozen = 450,
    map_play_fasterattackrate = 451,
    map_play_fastercastrate = 452,
    map_mon_skillondeath = 453,
    map_play_maxhp_percent = 454,
    map_play_maxmana_percent = 455,
    map_play_damageresist = 456,
    map_play_velocitypercent = 457,
    heroic = 458,
    extra_spirits = 459,
    gustreduction = 460,
    extra_skele_war = 461,
    extra_skele_mage = 462,
    extra_hydra = 463,
    extra_valk = 464,
    joustreduction = 465,
    grims_extra_skele_mage = 466,
    map_play_lightradius = 467,
    blood_warp_life_reduction = 468,
    pierce_count = 469,
    map_glob_add_mon_souls = 470,
    map_glob_add_mon_fetish = 471,
    dclone_clout = 472,
    maxlevel_clout = 473,
    dev_clout = 474,
    extra_skele_archer = 475,
    extra_golem = 476,
    transform_dye = 477,
    inc_splash_radius = 478,
    item_numsockets_textonly = 479,
    rathma_clout = 480,
    extra_holybolts = 481,
    pvp_cd = 482,
    dragonflightreduction = 483,
    item_dmgpercent_pereth = 484,
    corpseexplosionradius = 485,
    mirrored = 486,
    item_dmgpercent_permissinghppercent = 487,
    lifedrain_percentcap = 488,
    inc_splash_radius_permissinghp = 489,
    eaglehorn_raven = 490,
    pvp_disable = 491,
    pvp_lld_cd = 492,
    map_glob_skirmish_mode = 493,
    map_mon_dropjewelry = 494,
    map_mon_dropweapons = 495,
    map_mon_droparmor = 496,
    map_mon_dropcrafting = 497,
    map_glob_extra_boss = 498,
    map_glob_add_mon_shriek = 499,
    map_force_event = 500,
    deep_wounds = 501,
    map_mon_dropcharms = 502,
    map_glob_dropcorrupted = 503,
    curse_effectiveness = 504,
    map_glob_boss_dropfacet = 505,
    map_mon_dropjewels = 506,
    stat_507 = 507,
    stat_508 = 508,
    stat_509 = 509,
    stat_510 = 510,
    stat_511 = 511,
    stat_512 = 512,
};
