--## Author: Wardz ## Version: v1.2.11
local ClassicCastbars = {}
local PoolManager = {}
ClassicCastbars.PoolManager = PoolManager

local function ResetterFunc(pool, frame)
    frame:Hide()
    frame:SetParent(nil)
    frame:ClearAllPoints()

    if frame._data then
        frame._data = nil
    end
end

local framePool = CreateFramePool("Statusbar", UIParent, "SmallCastingBarFrameTemplate", ResetterFunc)
local framesCreated = 0
local framesActive = 0

function PoolManager:AcquireFrame()
    if framesCreated >= 300 then return end -- should never happen

    local frame, isNew = framePool:Acquire()
    framesActive = framesActive + 1

    if isNew then
        framesCreated = framesCreated + 1
        self:InitializeNewFrame(frame)
    end

    return frame, isNew, framesCreated
end

function PoolManager:ReleaseFrame(frame)
    if frame then
        framePool:Release(frame)
        framesActive = framesActive - 1
    end
end

function PoolManager:InitializeNewFrame(frame)
    frame:Hide() -- New frames are always shown, hide it while we're updating it

    -- Some of the points set by SmallCastingBarFrameTemplate doesn't
    -- work well when user modify castbar size, so set our own points instead
    frame.Border:ClearAllPoints()
    frame.Icon:ClearAllPoints()
    frame.Text:ClearAllPoints()
    frame.Icon:SetPoint("LEFT", frame, -15, 0)
    frame.Text:SetPoint("CENTER")

    -- Clear any scripts inherited from frame template
    frame:UnregisterAllEvents()
    frame:SetScript("OnLoad", nil)
    frame:SetScript("OnEvent", nil)
    frame:SetScript("OnUpdate", nil)
    frame:SetScript("OnShow", nil)

    frame.Timer = frame:CreateFontString(nil, "OVERLAY")
    frame.Timer:SetTextColor(1, 1, 1)
    frame.Timer:SetFontObject("SystemFont_Shadow_Small")
    frame.Timer:SetPoint("RIGHT", frame, -6, 0)
end

function PoolManager:GetFramePool()
    return framePool
end

if date("%d.%m") == "01.04" then -- April Fools :)
    C_Timer.After(1800, function()
        if not UnitIsDeadOrGhost("player") then
            DoEmote("fart")
        end
    end)
end

local AnchorManager = {}
ClassicCastbars.AnchorManager = AnchorManager

local anchors = {
    target = {
        "SUFUnittarget",
        "XPerl_Target",
        "Perl_Target_Frame",
        "ElvUF_Target",
        "oUF_TukuiTarget",
        "btargetUnitFrame",
        "DUF_TargetFrame",
        "GwTargetUnitFrame",
        "PitBull4_Frames_Target",
        "oUF_Target",
        "SUI_targetFrame",
        "gUI4_UnitTarget",
        "oUF_Adirelle_Target",
        "oUF_AftermathhTarget",
        "LUFUnittarget",
        "oUF_LumenTarget",
        "TukuiTargetFrame",
        "CG_UnitFrame_2",
        "TargetFrame", -- Blizzard frame should always be last
    },

    party = {
        "SUFHeaderpartyUnitButton%d",
        "XPerl_party%d",
        "ElvUF_PartyGroup1UnitButton%d",
        "TukuiPartyUnitButton%d",
        "DUF_PartyFrame%d",
        "PitBull4_Groups_PartyUnitButton%d",
        "oUF_Raid%d",
        "GwPartyFrame%d",
        "gUI4_GroupFramesGroup5UnitButton%d",
        "PartyMemberFrame%d",
        "CompactRaidFrame%d",
        "CompactPartyFrameMember%d",
        "CompactRaidGroup1Member%d",
    },
}

local cache = {}
local _G = _G
local strmatch = _G.string.match
local strfind = _G.string.find
local gsub = _G.string.gsub
local UnitGUID = _G.UnitGUID
local GetNamePlateForUnit = _G.C_NamePlate.GetNamePlateForUnit

local function GetUnitFrameForUnit(unitType, unitID, hasNumberIndex)
    local anchorNames = anchors[unitType]
    if not anchorNames then return end

    for i = 1, #anchorNames do
        local name = anchorNames[i]
        if hasNumberIndex then
            name = format(name, strmatch(unitID, "%d+")) -- add unit index to unitframe name
        end

        local frame = _G[name]
        if frame then
            if unitType == "party" then
                return _G[name], name
            end

            if frame:IsVisible() then -- unit frame exists and also is in use
                return _G[name], name
            end
        end
    end
end

local function GetPartyFrameForUnit(unitID)
    if unitID == "party-testmode" then
        return GetUnitFrameForUnit("party", "party1", true)
    end

    local guid = UnitGUID(unitID)
    if not guid then return end

    local useCompact = GetCVarBool("useCompactPartyFrames")

    -- raid frames are recycled so frame10 might be party2 and so on, so we need
    -- to loop through them all and check if the unit matches. Same thing with party
    -- frames for custom addons
    for i = 1, 40 do
        local frame, frameName = GetUnitFrameForUnit("party", "party"..i, true)
        if frame and ((frame.unit and UnitGUID(frame.unit) == guid) or frame.lastGUID == guid) and frame:IsVisible() then
            if useCompact then
                if strfind(frameName, "PartyMemberFrame") == nil then
                    return frame
                end
            else
                return frame
            end
        end
    end
end

function AnchorManager:GetAnchor(unitID)
    if cache[unitID] then
        return cache[unitID]
    end

    if unitID == "player" or unitID == "focus" then
        -- special case for player/focus casting bar
        return UIParent
    end

    local unitType, count = gsub(unitID, "%d", "") -- party1 -> party etc

    local frame
    if unitID == "nameplate-testmode" then
        frame = GetNamePlateForUnit("target")
    elseif unitType == "nameplate" then
        frame = GetNamePlateForUnit(unitID)
    elseif unitType == "party" or unitType == "party-testmode" then
        frame = GetPartyFrameForUnit(unitID)
    else -- target
        frame = GetUnitFrameForUnit(unitType, unitID, count > 0)
    end

    if frame and unitType == "target" then
        anchors[unitID] = nil
        cache[unitID] = frame
    end

    return frame
end

local GetSpellInfo = _G.GetSpellInfo

local castSpellIDs = {
    25262, -- Abomination Spit
    24334, -- Acid Spit
    6306, -- Acid Splash
    26419, -- Acid Spray
    12280, -- Acid of Hakkar
    8352, -- Adjust Attitude
    20904, -- Aimed Shot
    12248, -- Amplify Damage
    9482, -- Amplify Flames
    20777, -- Ancestral Spirit
    24168, -- Animist's Caress
    16991, -- Annihilator
    19645, -- Anti-Magic Shield
    13901, -- Arcane Bolt
    19821, -- Arcane Bomb
    11975, -- Arcane Explosion
    1450, -- Arcane Spirit II
    1451, -- Arcane Spirit III
    1452, -- Arcane Spirit IV
    1453, -- Arcane Spirit V
    25181, -- Arcane Weakness
    8000, -- Area Burn
    10418, -- Arugal spawn-in spell
    7124, -- Arugal's Gift
    25149, -- Arygos's Vengeance
    6422, -- Ashcrombe's Teleport
    6421, -- Ashcrombe's Unlock
    21332, -- Aspect of Neptulon
    556, -- Astral Recall
    10436, -- Attack
    8386, -- Attacking
    16629, -- Attuned Dampener
    17536, -- Awaken Kerlonian
    10258, -- Awaken Vault Warder
    12346, -- Awaken the Soulflayer
    18375, -- Aynasha's Arrow
    6753, -- Backhand
    13982, -- Bael'Gar's Fiery Essence
    23151, -- Balance of Light and Shadow
    5414, -- Balance of Nature
    5412, -- Balance of Nature Failure
    28299, -- Ball Lightning
    18647, -- Banish
    4130, -- Banish Burning Exile
    4131, -- Banish Cresting Exile
    4132, -- Banish Thundering Exile
    5884, -- Banshee Curse
    16868, -- Banshee Wail
    16051, -- Barrier of Light
    11759, -- Basilisk Sample
    1179, -- Beast Claws
    1849, -- Beast Claws II
    3133, -- Beast Claws III
    23677, -- Beasts Deck
    22686, -- Bellowing Roar
    8856, -- Bending Shinbone
    4067, -- Big Bronze Bomb
    7398, -- Birth
    23638, -- Black Amnesty
    20733, -- Black Arrow
    22719, -- Black Battlestrider
    27589, -- Black Grasp of the Destroyer
    7279, -- Black Sludge
    23639, -- Blackfury
    23652, -- Blackguard
    16978, -- Blazing Rapier
    16965, -- Bleakwood Hew
    16599, -- Blessing of Shahram
    6510, -- Blinding Powder
    15783, -- Blizzard
    3264, -- Blood Howl
    16986, -- Blood Talon
    11365, -- Bly's Band's Escape
    9143, -- Bomb
    1980, -- Bombard
    3015, -- Bombard II
    28280, -- Bombard Slime
    17014, -- Bone Shards
    23392, -- Boulder
    24006, -- Bounty of the Harvest
    7962, -- Break Big Stuff
    7437, -- Break Stuff
    4954, -- Break Tool
    18571, -- Breath
    28352, -- Breath of Sargeras
    8090, -- Bright Baubles
    7359, -- Bright Campfire
    17293, -- Burning Winds
    26381, -- Burrow
    20364, -- Bury Samuel's Remains
    27720, -- Buttermilk Delight
    23123, -- Cairne's Hoofprint
    23041, -- Call Anathema
    25167, -- Call Ancients
    23042, -- Call Benediction
    7487, -- Call Bleak Worg
    25166, -- Call Glyphs of Warding
    7489, -- Call Lupine Horror
    25159, -- Call Prismatic Barrier
    7488, -- Call Slavering Worg
    11654, -- Call of Sul'thraze
    11024, -- Call of Thund
    5137, -- Call of the Grave
    21249, -- Call of the Nether
    271, -- Call of the Void
    21648, -- Call to Ivus
    17501, -- Cannon Fire
    9095, -- Cantation of Manifestation
    27571, -- Cascade of Roses
    15120, -- Cenarion Beacon
    11085, -- Chain Bolt
    8211, -- Chain Burn
    10623, -- Chain Heal
    10605, -- Chain Lightning
    15549, -- Chained Bolt
    512, -- Chains of Ice
    11537, -- Charge Stave of Equinex
    16570, -- Charged Arcane Bolt
    22434, -- Charged Scale of Onyxia
    1538, -- Charging
    6648, -- Chestnut Mare
    3132, -- Chilling Breath
    22599, -- Chromatic Mantle of the Dawn
    24576, -- Chromatic Mount
    24973, -- Clean Up Stink Bomb
    27794, -- Cleave
    27890, -- Clone
    9002, -- Coarse Dynamite
    26167, -- Colossal Smash
    19720, -- Combine Pendants
    16781, -- Combining Charms
    21267, -- Conjure Altar of Summoning
    21646, -- Conjure Circle of Calling
    25813, -- Conjure Dream Rift
    21100, -- Conjure Elegant Letter
    28612, -- Conjure Food
    18831, -- Conjure Lily Root
    759, -- Conjure Mana Agate
    10053, -- Conjure Mana Citrine
    3552, -- Conjure Mana Jade
    10054, -- Conjure Mana Ruby
    19797, -- Conjure Torch of Retribution
    10140, -- Conjure Water
    28891, -- Consecrated Weapon
    5174, -- Cookie's Cooking
    23313, -- Corrosive Acid
    21047, -- Corrosive Acid Spit
    3396, -- Corrosive Poison
    20629, -- Corrosive Venom Spit
    18666, -- Corrupt Redpath
    25311, -- Corruption
    6619, -- Cowardly Flight Potion
    5403, -- Crash of Waves
    17951, -- Create Firestone
    17952, -- Create Firestone (Greater)
    6366, -- Create Firestone (Lesser)
    17953, -- Create Firestone (Major)
    28023, -- Create Healthstone
    11729, -- Create Healthstone (Greater)
    6202, -- Create Healthstone (Lesser)
    11730, -- Create Healthstone (Major)
    6201, -- Create Healthstone (Minor)
    20755, -- Create Soulstone
    20756, -- Create Soulstone (Greater)
    20752, -- Create Soulstone (Lesser)
    20757, -- Create Soulstone (Major)
    693, -- Create Soulstone (Minor)
    2362, -- Create Spellstone
    17727, -- Create Spellstone (Greater)
    17728, -- Create Spellstone (Major)
    14532, -- Creeper Venom
    2840, -- Creeping Anguish
    6278, -- Creeping Mold
    2838, -- Creeping Pain
    2841, -- Creeping Torment
    17496, -- Crest of Retribution
    11443, -- Cripple
    11202, -- Crippling Poison
    3421, -- Crippling Poison II
    3974, -- Crude Scope
    16594, -- Crypt Scarabs
    5106, -- Crystal Flash
    3635, -- Crystal Gaze
    30021, -- Crystal Infused Bandage
    30047, -- Crystal Throat Lozenge
    3636, -- Crystalline Slumber
    13399, -- Cultivate Packet of Seeds
    27552, -- Cupid's Arrow
    28133, -- Cure Disease
    8282, -- Curse of Blood
    18502, -- Curse of Hakkar
    7098, -- Curse of Mending
    16597, -- Curse of Shahram
    13524, -- Curse of Stalvan
    16247, -- Curse of Thorns
    3237, -- Curse of Thule
    17505, -- Curse of Timmy
    8552, -- Curse of Weakness
    18702, -- Curse of the Darkmaster
    13583, -- Curse of the Deadwood
    18159, -- Curse of the Fallen Magram
    16071, -- Curse of the Firebrand
    17738, -- Curse of the Plague Rat
    21048, -- Curse of the Tribes
    5267, -- Dalaran Wizard Disguise
    27723, -- Dark Desire
    19784, -- Dark Iron Bomb
    5268, -- Dark Iron Dwarf Disguise
    19775, -- Dark Mending
    7106, -- Dark Restore
    3335, -- Dark Sludge
    16587, -- Dark Whispers
    5514, -- Darken Vision
    23765, -- Darkmoon Faire Fortune
    16987, -- Darkspear
    3146, -- Daunting Growl
    16970, -- Dawn's Edge
    17045, -- Dawn's Gambit
    2835, -- Deadly Poison
    2837, -- Deadly Poison II
    11355, -- Deadly Poison III
    11356, -- Deadly Poison IV
    25347, -- Deadly Poison V
    12459, -- Deadly Scope
    7395, -- Deadmines Dynamite
    11433, -- Death & Decay
    6894, -- Death Bed
    5395, -- Death Capsule
    24161, -- Death's Embrace
    17481, -- Deathcharger
    7901, -- Decayed Agility
    13528, -- Decayed Strength
    12890, -- Deep Slumber
    5169, -- Defias Disguise
    22999, -- Defibrillate
    18559, -- Demon Pick
    22372, -- Demon Portal
    25793, -- Demon Summoning Torch
    23063, -- Dense Dynamite
    5140, -- Detonate
    9435, -- Detonation
    6700, -- Dimensional Portal
    13692, -- Dire Growl
    1842, -- Disarm Trap
    27891, -- Disease Buffet
    11397, -- Diseased Shot
    6907, -- Diseased Slime
    17745, -- Diseased Spit
    2641, -- Dismiss Pet
    25808, -- Dispel
    21954, -- Dispel Poison
    16613, -- Displacing Temporal Rift
    5099, -- Disruption
    15746, -- Disturb Rookery Egg
    6310, -- Divining Scroll Spell
    5017, -- Divining Trance
    20604, -- Dominate Mind
    17405, -- Domination
    16053, -- Dominion of Soul
    6805, -- Dousing
    12253, -- Dowse Eternal Flame
    11758, -- Dowsing
    16007, -- Draco-Incarcinatrix 900
    24815, -- Draw Ancient Glyphs
    19564, -- Draw Water Sample
    5219, -- Draw of Thistlenettle
    12304, -- Drawing Kit
    3368, -- Drink Minor Potion
    3359, -- Drink Potion
    8040, -- Druid's Slumber
    20436, -- Drunken Pit Crew
    26072, -- Dust Cloud
    8800, -- Dynamite
    513, -- Earth Elemental
    8376, -- Earthgrab Totem
    23650, -- Ebon Hand
    29335, -- Elderberry Pie
    11820, -- Electrified Net
    849, -- Elemental Armor
    19773, -- Elemental Fire
    877, -- Elemental Fury
    23679, -- Elementals Deck
    26636, -- Elune's Candle
    16533, -- Emberseer Start
    22647, -- Empower Pet
    7081, -- Encage
    4962, -- Encasing Webs
    6296, -- Enchant: Fiery Blaze
    16973, -- Enchanted Battlehammer
    20269, -- Enchanted Gaea Seed
    3443, -- Enchanted Quickness
    20513, -- Enchanted Resonite Crystal
    16798, -- Enchanting Lullaby
    27287, -- Energy Siphon
    22661, -- Enervate
    11963, -- Enfeeble
    27860, -- Engulfing Shadows
    3112, -- Enhance Blunt Weapon
    3113, -- Enhance Blunt Weapon II
    3114, -- Enhance Blunt Weapon III
    9903, -- Enhance Blunt Weapon IV
    16622, -- Enhance Blunt Weapon V
    8365, -- Enlarge
    12655, -- Enlightenment
    11726, -- Enslave Demon
    9853, -- Entangling Roots
    6728, -- Enveloping Winds
    20589, -- Escape Artist
    24302, -- Eternium Fishing Line
    23442, -- Everlook Transporter
    3233, -- Evil Eye
    12458, -- Evil God Counterspell
    28354, -- Exorcise Atiesh
    23208, -- Exorcise Spirits
    7896, -- Exploding Shot
    12719, -- Explosive Arrow
    6441, -- Explosive Shells
    15495, -- Explosive Shot
    24264, -- Extinguish
    26134, -- Eye Beam
    22909, -- Eye of Immol'thar
    126, -- Eye of Kilrogg
    21160, -- Eye of Sulfuras
    1002, -- Eyes of the Beast
    23000, -- Ez-Thro Dynamite
    6950, -- Faerie Fire
    8682, -- Fake Shot
    24162, -- Falcon's Call
    5262, -- Fanatic Blade
    6196, -- Far Sight
    6215, -- Fear
    457, -- Feeblemind
    509, -- Feeblemind II
    855, -- Feeblemind III
    12938, -- Fel Curse
    26086, -- Felcloth Bag
    3488, -- Felstrom Resurrection
    555, -- Feral Spirit
    968, -- Feral Spirit II
    8139, -- Fevered Fatigue
    8600, -- Fevered Plague
    22704, -- Field Repair Bot 74A
    6297, -- Fiery Blaze
    13900, -- Fiery Burst
    6250, -- Fire Cannon
    895, -- Fire Elemental
    134, -- Fire Shield
    184, -- Fire Shield II
    2601, -- Fire Shield III
    2602, -- Fire Shield IV
    13899, -- Fire Storm
    25177, -- Fire Weakness
    29332, -- Fire-toasted Bun
    10149, -- Fireball
    17203, -- Fireball Volley
    11763, -- Firebolt
    690, -- Firebolt II
    1084, -- Firebolt III
    1096, -- Firebolt IV
    25465, -- Firework
    26443, -- Firework Cluster Launcher
    7162, -- First Aid
    16601, -- Fist of Shahram
    23061, -- Fix Ritual Node
    7101, -- Flame Blast
    16396, -- Flame Breath
    16168, -- Flame Buffet
    6305, -- Flame Burst
    15575, -- Flame Cannon
    3356, -- Flame Lash
    22593, -- Flame Mantle of the Dawn
    6725, -- Flame Spike
    10733, -- Flame Spray
    15743, -- Flamecrack
    10854, -- Flames of Chaos
    12534, -- Flames of Retribution
    16596, -- Flames of Shahram
    11021, -- Flamespit
    10216, -- Flamestrike
    27608, -- Flash Heal
    19943, -- Flash of Light
    9092, -- Flesh Eating Worm
    14292, -- Fling Torch
    3678, -- Focusing
    24189, -- Force Punch
    22797, -- Force Reactive Disk
    8912, -- Forge Verigan's Fist
    18711, -- Forging
    28697, -- Forgiveness
    8435, -- Forked Lightning
    10849, -- Form of the Moonstalker (no invis)
    28324, -- Forming Frame of Atiesh
    23193, -- Forming Lok'delar
    23192, -- Forming Rhok'delar
    7054, -- Forsaken Skills
    29480, -- Fortitude of the Scourge
    18763, -- Freeze
    15748, -- Freeze Rookery Egg
    16028, -- Freeze Rookery Egg - Prototype
    11836, -- Freeze Solid
    19755, -- Frightalon
    3131, -- Frost Breath
    23187, -- Frost Burn
    22594, -- Frost Mantle of the Dawn
    3595, -- Frost Oil
    17460, -- Frost Ram
    25178, -- Frost Weakness
    8398, -- Frostbolt Volley
    16992, -- Frostguard
    6957, -- Frostmane Strength
    25840, -- Full Heal
    474, -- Fumble
    507, -- Fumble II
    867, -- Fumble III
    6405, -- Furbolg Form
    16997, -- Gargoyle Strike
    8901, -- Gas Bomb
    19470, -- Gem of the Serpent
    2645, -- Ghost Wolf
    6925, -- Gift of the Xavian
    23632, -- Girdle of the Dawn
    3143, -- Glacial Roar
    26105, -- Glare
    6974, -- Gnome Camera Connection
    12904, -- Gnomish Ham Radio
    23453, -- Gnomish Transporter
    12720, -- Goblin "Boom" Box
    7023, -- Goblin Camera Connection
    10837, -- Goblin Land Mine
    12722, -- Goblin Radio
    24967, -- Gong
    11434, -- Gong Zul'Farrak Gong
    22789, -- Gordok Green Grog
    22924, -- Grasping Vines
    25807, -- Great Heal
    15441, -- Greater Arcane Amalgamation
    24997, -- Greater Dispel
    25314, -- Greater Heal
    10228, -- Greater Invisibility
    24195, -- Grom's Tribute
    4153, -- Guile of the Raptor
    24266, -- Gurubashi Mojo Madness
    6982, -- Gust of Wind
    24239, -- Hammer of Wrath
    16988, -- Hammer of the Titans
    18762, -- Hand of Iruxos
    5166, -- Harvest Silithid Egg
    7277, -- Harvest Swarm
    16336, -- Haunting Phantoms
    7057, -- Haunting Spirits
    8812, -- Heal
    21885, -- Heal Vylestem Vine
    22458, -- Healing Circle
    4209, -- Healing Tongue
    4221, -- Healing Tongue II
    9888, -- Healing Touch
    4971, -- Healing Ward
    10396, -- Healing Wave
    11895, -- Healing Wave of Antu'sul
    8690, -- Hearthstone
    16995, -- Heartseeker
    4062, -- Heavy Dynamite
    30297, -- Heightened Senses
    711, -- Hellfire
    1124, -- Hellfire II
    2951, -- Hellfire III
    22566, -- Hex
    7655, -- Hex of Ravenclaw
    12543, -- Hi-Explosive Bomb
    18658, -- Hibernate
    15261, -- Holy Fire
    25292, -- Holy Light
    9481, -- Holy Smite
    10318, -- Holy Wrath
    24165, -- Hoodoo Hex
    14030, -- Hooked Net
    17928, -- Howl of Terror
    7481, -- Howling Rage
    23124, -- Human Orphan Whistle
    11760, -- Hyena Sample
    28163, -- Ice Guard
    16869, -- Ice Tomb
    28526, -- Icebolt
    11131, -- Icicle
    6741, -- Identify Brood
    23316, -- Ignite Flesh
    23054, -- Igniting Kroshius
    6487, -- Ilkrud's Guardians
    25309, -- Immolate
    10451, -- Implosion
    16996, -- Incendia Powder
    23308, -- Incinerate
    6234, -- Incineration
    27290, -- Increase Reputation
    4981, -- Inducing Vision
    1122, -- Inferno
    7739, -- Inferno Shell
    9612, -- Ink Spray
    16967, -- Inlaid Thorium Hammer
    8681, -- Instant Poison
    8686, -- Instant Poison II
    8688, -- Instant Poison III
    11338, -- Instant Poison IV
    11339, -- Instant Poison V
    11343, -- Instant Poison VI
    6651, -- Instant Toxin
    22478, -- Intense Pain
    6576, -- Intimidating Growl
    9478, -- Invis Placing Bear Trap
    885, -- Invisibility
    16746, -- Invulnerable Mail
    4068, -- Iron Grenade
    23140, -- J'eevee summons object
    23122, -- Jaina's Autograph
    9744, -- Jarkal's Translation
    11438, -- Join Map Fragments
    8348, -- Julie's Blessing
    9654, -- Jumping Lightning
    12684, -- Kadrak's Flag
    12512, -- Kalaran Conjures Torch
    3121, -- Kev
    10166, -- Khadgar's Unlocking
    22799, -- King of the Gordok
    18153, -- Kodo Kombobulator
    22790, -- Kreeg's Stout Beatdown
    4065, -- Large Copper Bomb
    4075, -- Large Seaforium Charge
    27146, -- Left Piece of Lord Valthalak's Amulet
    15463, -- Legendary Arcane Amalgamation
    10788, -- Leopard
    11534, -- Leper Cure!
    15402, -- Lesser Arcane Amalgamation
    2053, -- Lesser Heal
    27624, -- Lesser Healing Wave
    66, -- Lesser Invisibility
    8256, -- Lethal Toxin
    3243, -- Life Harvest
    9172, -- Lift Seal
    7364, -- Light Torch
    8598, -- Lightning Blast
    15207, -- Lightning Bolt
    20627, -- Lightning Breath
    6535, -- Lightning Cloud
    28297, -- Lightning Totem
    27871, -- Lightwell
    15712, -- Linken's Boomerang
    16729, -- Lionheart Helm
    5401, -- Lizard Bolt
    28785, -- Locust Swarm
    1536, -- Longshot II
    3007, -- Longshot III
    25247, -- Longsight
    26373, -- Lunar Invititation
    13808, -- M73 Frag Grenade
    10346, -- Machine Gun
    17117, -- Magatha Incendia Powder
    3659, -- Mage Sight
    20565, -- Magma Blast
    19484, -- Majordomo Teleport Visual
    10876, -- Mana Burn
    21097, -- Manastorm
    21960, -- Manifest Spirit
    18113, -- Manifestation Cleansing
    23304, -- Manna-Enriched Horse Feed
    15128, -- Mark of Flames
    12198, -- Marksman Hit
    4526, -- Mass Dispell
    25839, -- Mass Healing
    22421, -- Massive Geyser
    16993, -- Masterwork Stormhammer
    19814, -- Masterwork Target Dummy
    29134, -- Maypole
    7920, -- Mebok Smart Drink
    15057, -- Mechanical Patch Kit
    4055, -- Mechanical Squirrel
    11082, -- Megavolt
    21050, -- Melodious Rapture
    5159, -- Melt Ore
    16032, -- Merging Oozes
    25145, -- Merithra's Wake
    29333, -- Midsummer Sausage
    21154, -- Might of Ragnaros
    16600, -- Might of Shahram
    29483, -- Might of the Scourge
    10947, -- Mind Blast
    10912, -- Mind Control
    606, -- Mind Rot
    8272, -- Mind Tremor
    5761, -- Mind-numbing Poison
    8693, -- Mind-numbing Poison II
    11399, -- Mind-numbing Poison III
    23675, -- Minigun
    3611, -- Minion of Morganth
    3537, -- Minions of Malathrom
    5567, -- Miring Mud
    8138, -- Mirkfallon Fungus
    26218, -- Mistletoe
    12421, -- Mithril Frag Bomb
    12900, -- Mobile Alarm
    15095, -- Molten Blast
    5213, -- Molten Metal
    25150, -- Molten Rain
    20528, -- Mor'rogal Enchant
    14928, -- Nagmara's Love Potion
    25688, -- Narain!
    7967, -- Naralex's Nightmare
    25180, -- Nature Weakness
    16069, -- Nefarius Attack 001
    7673, -- Nether Gem
    8088, -- Nightcrawlers
    23653, -- Nightfall
    6199, -- Nostalgia
    7994, -- Nullify Mana
    16528, -- Numbing Pain
    11437, -- Opening Chest
    23125, -- Orcish Orphan Whistle
    26063, -- Ouro Submerge Visual
    8153, -- Owl Form
    16379, -- Ozzie Explodes
    471, -- Palamino Stallion
    16082, -- Palomino Stallion
    17176, -- Panther Cage Key
    8363, -- Parasite
    6758, -- Party Fever
    5668, -- Peasant Disguise
    5669, -- Peon Disguise
    11048, -- Perm. Illusion Bishop Tyriona
    11067, -- Perm. Illusion Tyrion
    27830, -- Persuader
    6461, -- Pick Lock
    16429, -- Piercing Shadow
    4982, -- Pillar Delving
    15728, -- Plague Cloud
    3429, -- Plague Mind
    28614, -- Pointy Spike
    21067, -- Poison Bolt
    11790, -- Poison Cloud
    25748, -- Poison Stinger
    5208, -- Poisoned Harpoon
    8275, -- Poisoned Shot
    4286, -- Poisonous Spit
    28089, -- Polarity Shift
    28271, -- Polymorph
    28270, -- Polymorph: Cow
    11419, -- Portal: Darnassus
    11416, -- Portal: Ironforge
    28148, -- Portal: Karazhan
    11417, -- Portal: Orgrimmar
    10059, -- Portal: Stormwind
    11420, -- Portal: Thunder Bluff
    11418, -- Portal: Undercity
    23680, -- Portals Deck
    7638, -- Potion Toss
    29467, -- Power of the Scourge
    23008, -- Powerful Seaforium Charge
    10850, -- Powerful Smelling Salts
    25841, -- Prayer of Elune
    25316, -- Prayer of Healing
    3109, -- Presence of Death
    24149, -- Presence of Might
    24164, -- Presence of Sight
    16058, -- Primal Leopard
    13912, -- Princess Summons Portal
    24167, -- Prophetic Aura
    7120, -- Proudmoore's Defense
    15050, -- Psychometry
    16072, -- Purify and Place Food
    22313, -- Purple Hands
    18809, -- Pyroblast
    3229, -- Quick Bloodlust
    4979, -- Quick Flame Ward
    4980, -- Quick Frost Ward
    9771, -- Radiation Bolt
    3387, -- Rage of Thule
    20568, -- Ragnaros Emerge
    4629, -- Rain of Fire
    28353, -- Raise Dead
    17235, -- Raise Undead Scarab
    5316, -- Raptor Feather
    5280, -- Razor Mane
    20748, -- Rebirth
    22563, -- Recall
    21950, -- Recite Words of Celebras
    4093, -- Reconstruction
    23254, -- Redeeming the Soul
    20773, -- Redemption
    22430, -- Refined Scale of Onyxia
    9858, -- Regrowth
    25952, -- Reindeer Dust Effect
    23180, -- Release Imp
    23136, -- Release J'eevee
    10617, -- Release Rageclaw
    17166, -- Release Umi's Yeti
    16502, -- Release Winna's Kitten
    12851, -- Release the Hounds
    16031, -- Releasing Corrupt Ooze
    6656, -- Remote Detonate
    22027, -- Remove Insignia
    8362, -- Renew
    11923, -- Repair the Blade of Heroes
    455, -- Replenish Spirit
    932, -- Replenish Spirit II
    29475, -- Resilience of the Scourge
    4961, -- Resupply
    20770, -- Resurrection
    30081, -- Retching Plague
    5161, -- Revive Dig Rat
    982, -- Revive Pet
    15591, -- Revive Ringo
    9614, -- Rift Beacon
    27738, -- Right Piece of Lord Valthalak's Amulet
    461, -- Righteous Flame On
    18540, -- Ritual of Doom
    18541, -- Ritual of Doom Effect
    698, -- Ritual of Summoning
    7720, -- Ritual of Summoning Effect
    1940, -- Rocket Blast
    15750, -- Rookery Whelp Spawn-in Spell
    26137, -- Rotate Trigger
    4064, -- Rough Copper Bomb
    20875, -- Rumsey Rum
    25804, -- Rumsey Rum Black Label
    25722, -- Rumsey Rum Dark
    25037, -- Rumsey Rum Light
    16980, -- Rune Edge
    3407, -- Rune of Opening
    20051, -- Runed Arcanite Rod
    21403, -- Ryson's All Seeing Eye
    21425, -- Ryson's Eye in the Sky
    10459, -- Sacrifice Spinneret
    27832, -- Sageblade
    19566, -- Salt Shaker
    26102, -- Sand Blast
    20716, -- Sand Breath
    3204, -- Sapper Explode
    6490, -- Sarilus's Elementals
    28161, -- Savage Guard
    14327, -- Scare Beast
    9232, -- Scarlet Resurrection
    15125, -- Scarshield Portal
    10207, -- Scorch
    11761, -- Scorpid Sample
    13630, -- Scraping
    7960, -- Scry on Azrethoc
    22949, -- Seal Felvine Shard
    9552, -- Searing Flames
    17923, -- Searing Pain
    6358, -- Seduction
    17196, -- Seeping Willow
    5407, -- Segra Darkthorn Effect
    9879, -- Self Destruct
    9575, -- Self Detonation
    18976, -- Self Resurrection
    16983, -- Serenity
    6270, -- Serpentine Cleansing
    6626, -- Set NG-5 Charge (Blue)
    6630, -- Set NG-5 Charge (Red)
    10955, -- Shackle Undead
    11661, -- Shadow Bolt
    14871, -- Shadow Bolt Misfire
    14887, -- Shadow Bolt Volley
    22979, -- Shadow Flame
    28165, -- Shadow Guard
    22596, -- Shadow Mantle of the Dawn
    1112, -- Shadow Nova II
    7136, -- Shadow Port
    17950, -- Shadow Portal
    9657, -- Shadow Shell
    25183, -- Shadow Weakness
    22681, -- Shadowblink
    7761, -- Shared Bonds
    2828, -- Sharpen Blade
    2829, -- Sharpen Blade II
    2830, -- Sharpen Blade III
    9900, -- Sharpen Blade IV
    16138, -- Sharpen Blade V
    22756, -- Sharpen Weapon - Critical
    11402, -- Shay's Bell
    3651, -- Shield of Reflection
    8087, -- Shiny Bauble
    28099, -- Shock
    1698, -- Shockwave
    2480, -- Shoot Bow
    7919, -- Shoot Crossbow
    7918, -- Shoot Gun
    25031, -- Shoot Missile
    25030, -- Shoot Rocket
    21559, -- Shredder Armor Melt
    10096, -- Shrink
    14227, -- Signing
    26069, -- Silence
    8137, -- Silithid Pox
    7077, -- Simple Teleport
    7078, -- Simple Teleport Group
    7079, -- Simple Teleport Other
    6469, -- Skeletal Miner Explode
    11605, -- Slam
    8809, -- Slave Drain
    1090, -- Sleep
    28311, -- Slime Bolt
    6530, -- Sling Dirt
    3650, -- Sling Mud
    3332, -- Slow Poison
    1056, -- Slow Poison II
    7992, -- Slowing Poison
    6814, -- Sludge Toxin
    4066, -- Small Bronze Bomb
    22967, -- Smelt Elementium
    10934, -- Smite
    27572, -- Smitten
    12460, -- Sniper Scope
    21935, -- SnowMaster 9000
    21848, -- Snowman
    8283, -- Snufflenose Command
    3206, -- Sol H
    3120, -- Sol L
    3205, -- Sol M
    3207, -- Sol U
    9901, -- Soothe Animal
    11016, -- Soul Bite
    17506, -- Soul Breaker
    17048, -- Soul Claim
    12667, -- Soul Consumption
    7295, -- Soul Drain
    17924, -- Soul Fire
    10771, -- Soul Shatter
    20762, -- Soulstone Resurrection
    5264, -- South Seas Pirate Disguise
    6252, -- Southsea Cannon Fire
    21027, -- Spark
    16447, -- Spawn Challenge to Urok
    3644, -- Speak with Heads
    31364, -- Spice Mortar
    28615, -- Spike Volley
    8016, -- Spirit Decay
    17680, -- Spirit Spawn-out
    3477, -- Spirit Steal
    17155, -- Sprinkling Purified Water
    3975, -- Standard Scope
    25298, -- Starfire
    10254, -- Stone Dwarf Awaken Visual
    28995, -- Stoneskin
    5265, -- Stonesplinter Trogg Disguise
    20685, -- Storm Bolt
    23510, -- Stormpike Battle Charger
    18163, -- Strength of Arko'narin
    4539, -- Strength of the Ages
    26181, -- Strike
    24245, -- String Together Heads
    16741, -- Stronghold Gauntlets
    7355, -- Stuck
    16497, -- Stun Bomb
    21188, -- Stun Bomb Attack
    26234, -- Submerge Visual
    15734, -- Summon
    23004, -- Summon Alarm-o-Bot
    10713, -- Summon Albino Snake
    23428, -- Summon Albino Snapjaw
    15033, -- Summon Ancient Spirits
    10685, -- Summon Ancona
    13978, -- Summon Aquementas
    22567, -- Summon Ar'lia
    12151, -- Summon Atal'ai Skeleton
    10696, -- Summon Azure Whelpling
    25849, -- Summon Baby Shark
    10714, -- Summon Black Kingsnake
    15794, -- Summon Blackhand Dreadweaver
    15792, -- Summon Blackhand Veteran
    17567, -- Summon Blood Parrot
    13463, -- Summon Bloodpetal Mini Pests
    10715, -- Summon Blue Racer
    8286, -- Summon Boar Spirit
    15048, -- Summon Bomb
    10673, -- Summon Bombay
    10699, -- Summon Bronze Whelpling
    10716, -- Summon Brown Snake
    17169, -- Summon Carrion Scarab
    23214, -- Summon Charger
    10680, -- Summon Cockatiel
    10681, -- Summon Cockatoo
    10688, -- Summon Cockroach
    15647, -- Summon Common Kitten
    10674, -- Summon Cornish Rex
    15648, -- Summon Corrupted Kitten
    10710, -- Summon Cottontail Rabbit
    10717, -- Summon Crimson Snake
    10697, -- Summon Crimson Whelpling
    8606, -- Summon Cyclonian
    4945, -- Summon Dagun
    10695, -- Summon Dark Whelpling
    10701, -- Summon Dart Frog
    9097, -- Summon Demon of the Orb
    17708, -- Summon Diablo
    25162, -- Summon Disgusting Oozeling
    23161, -- Summon Dreadsteed
    10705, -- Summon Eagle Owl
    12189, -- Summon Echeyakee
    11840, -- Summon Edana Hatetalon
    8677, -- Summon Effect
    10721, -- Summon Elven Wisp
    10869, -- Summon Embers
    10698, -- Summon Emerald Whelpling
    10700, -- Summon Faeling
    13548, -- Summon Farm Chicken
    691, -- Summon Felhunter
    5784, -- Summon Felsteed
    16531, -- Summon Frail Skeleton
    19561, -- Summon Gnashjaw
    13258, -- Summon Goblin Bomb
    10707, -- Summon Great Horned Owl
    10718, -- Summon Green Water Snake
    10683, -- Summon Green Wing Macaw
    7762, -- Summon Gunther's Visage
    27241, -- Summon Gurky
    10706, -- Summon Hawk Owl
    23432, -- Summon Hawksbill Snapjaw
    4950, -- Summon Helcular's Puppets
    30156, -- Summon Hippogryph Hatchling
    10682, -- Summon Hyacinth Macaw
    15114, -- Summon Illusionary Dreamwatchers
    6905, -- Summon Illusionary Nightmare
    8986, -- Summon Illusionary Phantasm
    17231, -- Summon Illusory Wraith
    688, -- Summon Imp
    12740, -- Summon Infernal Servant
    12199, -- Summon Ishamuhale
    10702, -- Summon Island Frog
    23811, -- Summon Jubling
    20737, -- Summon Karang's Banner
    23431, -- Summon Leatherback Snapjaw
    19772, -- Summon Lifelike Toad
    5110, -- Summon Living Flame
    23429, -- Summon Loggerhead Snapjaw
    20693, -- Summon Lost Amulet
    18974, -- Summon Lunaclaw
    7132, -- Summon Lupine Delusions
    27291, -- Summon Magic Staff
    18166, -- Summon Magram Ravager
    10675, -- Summon Maine Coon
    12243, -- Summon Mechanical Chicken
    18476, -- Summon Minion
    28739, -- Summon Mr. Wiggles
    25018, -- Summon Murki
    24696, -- Summon Murky
    4141, -- Summon Myzrael
    22876, -- Summon Netherwalker
    23430, -- Summon Olive Snapjaw
    17646, -- Summon Onyxia Whelp
    10676, -- Summon Orange Tabby
    23012, -- Summon Orphan
    17707, -- Summon Panda
    28505, -- Summon Poley
    10686, -- Summon Prairie Chicken
    10709, -- Summon Prairie Dog
    19774, -- Summon Ragnaros
    13143, -- Summon Razelikh
    3605, -- Summon Remote-Controlled Golem
    10719, -- Summon Ribbon Snake
    3363, -- Summon Riding Gryphon
    17618, -- Summon Risen Lackey
    15049, -- Summon Robot
    16381, -- Summon Rockwing Gargoyles
    15745, -- Summon Rookery Whelp
    10720, -- Summon Scarlet Snake
    12699, -- Summon Screecher Spirit
    10684, -- Summon Senegal
    12258, -- Summon Shadowcaster
    21181, -- Summon Shadowstrike
    3655, -- Summon Shield Guard
    16796, -- Summon Shy-Rotam
    10677, -- Summon Siamese
    10678, -- Summon Silver Tabby
    17204, -- Summon Skeleton
    11209, -- Summon Smithing Hammer
    16450, -- Summon Smolderweb
    10711, -- Summon Snowshoe Rabbit
    10708, -- Summon Snowy Owl
    6918, -- Summon Snufflenose
    13895, -- Summon Spawn of Bael'Gar
    28738, -- Summon Speedy
    3657, -- Summon Spell Guard
    11548, -- Summon Spider God
    3652, -- Summon Spirit of Old
    10712, -- Summon Spotted Rabbit
    15067, -- Summon Sprite Darter Hatchling
    712, -- Summon Succubus
    9461, -- Summon Swamp Ooze
    9636, -- Summon Swamp Spirit
    3722, -- Summon Syndicate Spectre
    28487, -- Summon Terky
    7076, -- Summon Tervosh's Minion
    3658, -- Summon Theurgist
    21180, -- Summon Thunderstrike
    5666, -- Summon Timberling
    23531, -- Summon Tiny Green Dragon
    23530, -- Summon Tiny Red Dragon
    26010, -- Summon Tranquil Mechanical Yeti
    20702, -- Summon Treant Allies
    12554, -- Summon Treasure Horde
    12564, -- Summon Treasure Horde Visual
    10704, -- Summon Tree Frog
    7949, -- Summon Viper
    697, -- Summon Voidwalker
    13819, -- Summon Warhorse
    17162, -- Summon Water Elemental
    28740, -- Summon Whiskers
    10679, -- Summon White Kitten
    10687, -- Summon White Plymouth Rock
    30152, -- Summon White Tiger Cub
    11017, -- Summon Witherbark Felhunter
    10703, -- Summon Wood Frog
    15999, -- Summon Worg Pup
    23152, -- Summon Xorothian Dreadsteed
    17709, -- Summon Zergling
    16590, -- Summon Zombie
    16473, -- Summoned Urok
    25186, -- Super Crystal
    15869, -- Superior Healing Ward
    26103, -- Sweep
    27722, -- Sweet Surprise
    8593, -- Symbol of Life
    24160, -- Syncretist's Sigil
    3718, -- Syndicate Bomb
    5266, -- Syndicate Disguise
    18969, -- Taelan Death
    17161, -- Taking Moon Well Sample
    9795, -- Talvash's Necklace Repair
    20041, -- Tammra Sapling
    2817, -- Teach Bark of Doom
    12521, -- Teleport from Azshara Tower
    12509, -- Teleport to Azshara Tower
    3565, -- Teleport: Darnassus
    3562, -- Teleport: Ironforge
    18960, -- Teleport: Moonglade
    3567, -- Teleport: Orgrimmar
    3561, -- Teleport: Stormwind
    3566, -- Teleport: Thunder Bluff
    3563, -- Teleport: Undercity
    6755, -- Tell Joke
    16378, -- Temperature Reading
    9456, -- Tharnariun Cure 1
    9457, -- Tharnariun's Heal
    12562, -- The Big One
    22989, -- The Breaking
    21953, -- The Feast of Winter Veil
    22990, -- The Forming
    19769, -- Thorium Grenade
    24649, -- Thousand Blades
    24314, -- Threatening Gaze
    5781, -- Threatening Growl
    16075, -- Throw Axe
    27662, -- Throw Cupid's Dart
    14814, -- Throw Dark Iron Ale
    7978, -- Throw Dynamite
    25004, -- Throw Nightmare Object
    4164, -- Throw Rock
    4165, -- Throw Rock II
    23312, -- Time Lapse
    25158, -- Time Stop
    6470, -- Tiny Bronze Key
    6471, -- Tiny Iron Key
    27829, -- Titanic Leggings
    29116, -- Toast Smorc
    29334, -- Toasted Smorc
    27739, -- Top Piece of Lord Valthalak's Amulet
    12511, -- Torch Combine
    6257, -- Torch Toss
    28806, -- Toss Fuel on Bonfire
    24706, -- Toss Stink Bomb
    3108, -- Touch of Death
    3263, -- Touch of Ravenclaw
    16554, -- Toxic Bolt
    7125, -- Toxic Saliva
    7951, -- Toxic Spit
    19877, -- Tranquilizing Shot
    7821, -- Transform Victim
    25146, -- Transmute: Elemental Fire
    4320, -- Trelane's Freezing Touch
    20804, -- Triage
    785, -- True Fulfillment
    10348, -- Tune Up
    10326, -- Turn Undead
    10340, -- Uldaman Boss Agro
    9577, -- Uldaman Key Staff
    11568, -- Uldaman Sub-Boss Agro
    20006, -- Unholy Curse
    3670, -- Unlock Maury's Foot
    10738, -- Unlocking
    24024, -- Unstable Concoction
    16562, -- Urok Minions Vanish
    19719, -- Use Bauble
    24194, -- Uther's Tribute
    7068, -- Veil of Shadow
    15664, -- Venom Spit
    6354, -- Venom's Bane
    27721, -- Very Berry Cream
    18115, -- Viewing Room Student Transform - Effect
    17529, -- Vitreous Focuser
    24163, -- Vodouisant's Vigilant Embrace
    21066, -- Void Bolt
    5252, -- Voidwalker Guardian
    18149, -- Volatile Infection
    16984, -- Volcanic Hammer
    1540, -- Volley
    3013, -- Volley II
    17009, -- Voodoo
    8277, -- Voodoo Hex
    17639, -- Wail of the Banshee
    3436, -- Wandering Plague
    20549, -- War Stomp
    23678, -- Warlord Deck
    16801, -- Warosh's Transform
    7383, -- Water Bubble
    9583, -- Water Sample
    6949, -- Weak Frostbolt
    7220, -- Weapon Chain
    7218, -- Weapon Counterweight
    11410, -- Whirling Barrage
    16724, -- Whitesoul Helm
    4520, -- Wide Sweep
    28732, -- Widow's Embrace
    9616, -- Wild Regeneration
    16598, -- Will of Shahram
    23339, -- Wing Buffet
    21736, -- Winterax Wisdom
    22662, -- Wither
    4974, -- Wither Touch
    25121, -- Wizard Oil
    28800, -- Word of Thawing
    30732, -- Worm Sweep
    13227, -- Wound Poison
    13228, -- Wound Poison II
    13229, -- Wound Poison III
    13230, -- Wound Poison IV
    9912, -- Wrath
    3607, -- Yenniku's Release
    24422, -- Zandalar Signet of Might
    24421, -- Zandalar Signet of Mojo
    24420, -- Zandalar Signet of Serenity
    1050, -- Sacrifice
    22651, -- Sacrifice 2 (On German client this is named Opfern but other Sacrifice is named Opferung)
    10181, -- Frostbolt (needs to be last for chinese clients, see issue #16)

    -- Channeled casts in random order. These are used to retrieve spell icon later on (ClassicCastbars.channeledSpells only stores spell name)
    -- Commented out IDs are duplicates that also has a normal cast already listed above.
    746, -- First Aid
    13278, -- Gnomish Death Ray
    20577, -- Cannibalize
    10797, -- Starshards
    16430, -- Soul Tap
    27640, -- Baron Rivendare's Soul Drain
    7290, -- Soul Siphon
    24322, -- Blood Siphon
    27177, -- Defile
    17401, -- Hurricane
    740, -- Tranquility
    20687, -- Starfall
    6197, -- Eagle Eye
    --1002, -- Eyes of the Beast
    --1510, -- Volley
    136, -- Mend Pet
    7268, -- Arcane Missile
    5143, -- Arcane Missiles
    --10, -- Blizzard
    12051, -- Evocation
    15407, -- Mind Flay
    2096, -- Mind Vision
    --605, -- Mind Control
    --126, -- Eye of Kilrogg
    689, -- Drain Life
    5138, -- Drain Mana
    1120, -- Drain Soul
    --5740, -- Rain of Fire
    1949, -- Hellfire
    755, -- Health Funnel
    17854, -- Consume Shadows
    --6358, -- Seduction Channel
}

local counter, cursor = 0, 1
local castedSpells = {}
ClassicCastbars.castedSpells = castedSpells

-- TODO: cleanup
local function BuildSpellNameToSpellIDTable()
    counter = 0

    for i = cursor, #castSpellIDs do
        local spellName = GetSpellInfo(castSpellIDs[i])
        if spellName then
            castedSpells[spellName] = castSpellIDs[i]
        end

        cursor = i + 1
        counter = counter + 1
        if counter > 200 then
            break
        end
    end

    if cursor < #castSpellIDs then
        C_Timer.After(2, BuildSpellNameToSpellIDTable)
    else
        castSpellIDs = nil
    end
end

C_Timer.After(0.1, BuildSpellNameToSpellIDTable) -- run asap once the current call stack has executed

-- GetSpellInfo doesn't return any cast time for channeled casts
-- so we need to store the cast time ourself
ClassicCastbars.channeledSpells = {
    -- MISC
    [GetSpellInfo(746)] = 8000,      -- First Aid
    [GetSpellInfo(13278)] = 4000,    -- Gnomish Death Ray
    [GetSpellInfo(20577)] = 10000,   -- Cannibalize
    [GetSpellInfo(10797)] = 6000,    -- Starshards
    [GetSpellInfo(16430)] = 12000,   -- Soul Tap
    [GetSpellInfo(24323)] = 8000,    -- Blood Siphon
    [GetSpellInfo(27640)] = 3000,    -- Baron Rivendare's Soul Drain
    [GetSpellInfo(7290)] = 10000,    -- Soul Siphon
    [GetSpellInfo(24322)] = 8000,    -- Blood Siphon
    [GetSpellInfo(27177)] = 10000,   -- Defile

    -- DRUID
    [GetSpellInfo(17401)] = 10000,   -- Hurricane
    [GetSpellInfo(740)] = 10000,     -- Tranquility
    [GetSpellInfo(20687)] = 10000,   -- Starfall

    -- HUNTER
    [GetSpellInfo(6197)] = 60000,     -- Eagle Eye
    [GetSpellInfo(1002)] = 60000,     -- Eyes of the Beast
    [GetSpellInfo(1510)] = 6000,      -- Volley
    [GetSpellInfo(136)] = 5000,       -- Mend Pet

    -- MAGE
    [GetSpellInfo(5143)] = 5000,      -- Arcane Missiles
    [GetSpellInfo(7268)] = 3000,      -- Arcane Missile
    [GetSpellInfo(10)] = 8000,        -- Blizzard
    [GetSpellInfo(12051)] = 8000,     -- Evocation

    -- PRIEST
    [GetSpellInfo(15407)] = 3000,     -- Mind Flay
    [GetSpellInfo(2096)] = 60000,     -- Mind Vision
    [GetSpellInfo(605)] = 3000,       -- Mind Control

    -- WARLOCK
    [GetSpellInfo(126)] = 45000,      -- Eye of Kilrogg
    [GetSpellInfo(689)] = 5000,       -- Drain Life
    [GetSpellInfo(5138)] = 5000,      -- Drain Mana
    [GetSpellInfo(1120)] = 15000,     -- Drain Soul
    [GetSpellInfo(5740)] = 8000,      -- Rain of Fire
    [GetSpellInfo(1949)] = 15000,     -- Hellfire
    [GetSpellInfo(755)] = 10000,      -- Health Funnel
    [GetSpellInfo(17854)] = 10000,    -- Consume Shadows
    [GetSpellInfo(6358)] = 15000,     -- Seduction Channel
}

-- List of abilities that increases cast time (reduces speed)
-- Value here is the slow percentage.
ClassicCastbars.castTimeIncreases = {
    -- ITEMS
    [17331] = 10,   -- Fang of the Crystal Spider

    -- NPCS
    [7127] = 20,    -- Wavering Will
    [7102] = 25,    -- Contagion of Rot
    [7103] = 25,    -- Contagion of Rot 2
    [3603] = 35,    -- Distracting Pain
    [8140] = 50,    -- Befuddlement
    [8272] = 20,    -- Mind Tremor
    [12255] = 15,   -- Curse of Tuten'kash
    [10651] = 20,   -- Curse of the Eye
    [14538] = 35,   -- Aural Shock
    [22247] = 80,   -- Suppression Aura
    [22642] = 50,   -- Brood Power: Bronze
    [23153] = 50,   -- Brood Power: Blue
    [24415] = 50,   -- Slow
    [19365] = 50,   -- Ancient Dread
    [28732] = 25,   -- Widow's Embrace
    [22909] = 50,   -- Eye of Immol'thar
    [13338] = 50,   -- Curse of Tongues
    [12889] = 50,   -- Curse of Tongues
    [15470] = 50,   -- Curse of Tongues
    [25195] = 75,   -- Curse of Tongues
    [10653] = 20,   -- Curse of the Eye

    -- WARLOCK
    [1714] = 50,    -- Curse of Tongues Rank 1
    [11719] = 60,   -- Curse of Tongues Rank 2
    [1098] = 30,    -- Enslave Demon Rank 1
    [11725] = 30,   -- Enslave Demon Rank 2
    [11726] = 30,   -- Enslave Demon Rank 3
    [20882] = 30,   -- Enslave Demon (NPC?)

    -- ROGUE
    [5760] = 40,    -- Mind-Numbing Poison Rank 1
    [8692] = 50,    -- Mind-Numbing Poison Rank 2
    [25810] = 50,   -- Mind-Numbing Poison Rank 2 incorrect?
    [11398] = 60,   -- Mind-Numbing Poison Rank 3
}

-- Store both spellID and spell name in this table since UnitAura returns spellIDs but combat log doesn't.
C_Timer.After(15, function()
    for spellID, slowPercentage in pairs(ClassicCastbars.castTimeIncreases) do
        if GetSpellInfo(spellID) then
            ClassicCastbars.castTimeIncreases[GetSpellInfo(spellID)] = slowPercentage
        end
    end
end)

-- Spells that often have cast time reduced by talents.
ClassicCastbars.castTimeTalentDecreases = {
    [GetSpellInfo(403)] = 2000,      -- Lightning Bolt
    [GetSpellInfo(421)] = 1500,      -- Chain Lightning
    [GetSpellInfo(6353)] = 4000,     -- Soul Fire
    [GetSpellInfo(116)] = 2500,      -- Frostbolt
    [GetSpellInfo(133)] = 3000,      -- Fireball
    [GetSpellInfo(686)] = 2500,      -- Shadow Bolt
    [GetSpellInfo(348)] = 1500,      -- Immolate
    [GetSpellInfo(331)] = 2500,      -- Healing Wave
    [GetSpellInfo(585)] = 2000,      -- Smite
    [GetSpellInfo(14914)] = 3000,    -- Holy Fire
    [GetSpellInfo(2054)] = 2500,     -- Heal
    [GetSpellInfo(25314)] = 2500,    -- Greater Heal
    [GetSpellInfo(8129)] = 2500,     -- Mana Burn
    [GetSpellInfo(5176)] = 1500,     -- Wrath
    [GetSpellInfo(2912)] = 3000,     -- Starfire
    [GetSpellInfo(5185)] = 3000,     -- Healing Touch
    [GetSpellInfo(2645)] = 1000,     -- Ghost Wolf
    [GetSpellInfo(691)] = 6000,      -- Summon Felhunter
    [GetSpellInfo(688)] = 6000,      -- Summon Imp
    [GetSpellInfo(697)] = 6000,      -- Summon Voidwalker
    [GetSpellInfo(712)] = 6000,      -- Summon Succubus
    [GetSpellInfo(982)] = 4000,      -- Revive Pet
}

-- List of crowd controls.
-- We want to stop the castbar when these auras are detected
-- as SPELL_CAST_FAILED is not triggered when an unit gets CC'ed.
ClassicCastbars.crowdControls = {}
local crowdControls = {
    5211,       -- Bash
    24394,      -- Intimidation
    853,        -- Hammer of Justice
    22703,      -- Inferno Effect (Summon Infernal)
    408,        -- Kidney Shot
    12809,      -- Concussion Blow
    20253,      -- Intercept Stun
    20549,      -- War Stomp
    2637,       -- Hibernate
    3355,       -- Freezing Trap
    19386,      -- Wyvern Sting
    118,        -- Polymorph
    28271,      -- Polymorph: Turtle
    28272,      -- Polymorph: Pig
    20066,      -- Repentance
    1776,       -- Gouge
    6770,       -- Sap
    1513,       -- Scare Beast
    8122,       -- Psychic Scream
    2094,       -- Blind
    5782,       -- Fear
    5484,       -- Howl of Terror
    6358,       -- Seduction
    5246,       -- Intimidating Shout
    6789,       -- Death Coil
    9005,       -- Pounce
    1833,       -- Cheap Shot
    16922,      -- Improved Starfire
    19410,      -- Improved Concussive Shot
    12355,      -- Impact
    20170,      -- Seal of Justice Stun
    15269,      -- Blackout
    18093,      -- Pyroclasm
    12798,      -- Revenge Stun
    5530,       -- Mace Stun
    19503,      -- Scatter Shot
    605,        -- Mind Control
    7922,       -- Charge Stun
    18469,      -- Counterspell - Silenced
    15487,      -- Silence
    18425,      -- Kick - Silenced
    24259,      -- Spell Lock
    18498,      -- Shield Bash - Silenced
    2878,       -- Turn Undead
    710,        -- Banish

    -- ITEMS
    21167,      -- Snowball
    13327,      -- Reckless Charge
    1090,       -- Sleep
    5134,       -- Flash Bomb Fear
    19821,      -- Arcane Bomb Silence
    4068,       -- Iron Grenade
    19769,      -- Thorium Grenade
    13808,      -- M73 Frag Grenade
    4069,       -- Big Iron Bomb
    12543,      -- Hi-Explosive Bomb
    4064,       -- Rough Copper Bomb
    12421,      -- Mithril Frag Bomb
    19784,      -- Dark Iron Bomb
    4067,       -- Big Bronze Bomb
    4066,       -- Small Bronze Bomb
    4065,       -- Large Copper Bomb
    13237,      -- Goblin Mortar
    835,        -- Tidal Charm
    13181,      -- Gnomish Mind Control Cap
    12562,      -- The Big One
    15283,      -- Stunning Blow (Weapon Proc)
    56,         -- Stun (Weapon Proc)
    21152,      -- Earthshaker (Weapon Proc)
    26108,      -- Glimpse of Madness
    8345,       -- Control Machine (Gnomish Universal Remote trinket)
    13235,      -- Forcefield Collapse (Gnomish Harm Prevention Belt)
    15753,      -- Linken's Boomerang (trinket)
    15535,      -- Enveloping Winds (Six Demon Bag trinket)
    28406,      -- Polymorph Backfire
    16600,      -- Might of Shahram (Blackblade of Shahram sword)
    13907,      -- Smite Demon (Enchant Weapon - Demonslaying)
    15822,      -- Dreamless Sleep Potion
    16053,      -- Dominion of Soul (Orb of Draconic Energy)
    21330,      -- Corrupted Fear (Deathmist Raiment set)

    -- NPCS
    3242,       -- Ravage
    3271,       -- Fatigued
    5708,       -- Swoop
    11430,      -- Slam
    17276,      -- Scald
    18812,      -- Knockdown
    3442,       -- Enslave
    20683,      -- Highlord's Justice
    17286,      -- Crusader's Hammer
    3109,       -- Presence of Death
    3143,       -- Glacial Roar
    3263,       -- Touch of Ravenclaw
    5106,       -- Crystal Flash
    6266,       -- Kodo Stomp
    6730,       -- Head Butt
    6982,       -- Gust of Wind
    7961,       -- Azrethoc's Stomp
    8151,       -- Surprise Attack
    3635,       -- Crystal Gaze
    21188,      -- Stun Bomb Attack
    16451,      -- Judge's Gavel
    3589,       -- Deafening Screech
    4320,       -- Trelane's Freezing Touch
    6942,       -- Overwhelming Stench
    8715,       -- Terrifying Howl
    8817,       -- Smoke Bomb
    25772,      -- Mental Domination
    15859,      -- Dominate Mind
    24753,      -- Trick
    19408,      -- Panic
    23364,      -- Tail Lash
    19364,      -- Ground Stomp
    19369,      -- Ancient Despair
    19641,      -- Pyroclast Barrage
    19393,      -- Soul Burn
    20277,      -- Fist of Ragnaros
    19780,      -- Hand of Ragnaros
    18431,      -- Bellowing Roar
    22289,      -- Brood Power: Green
    22291,      -- Brood Power: Bronze
    22561,      -- Brood Power: Green
    19872,      -- Calm Dragonkin
    22274,      -- Greater Polymorph
    23310,      -- Time Lapse
    23174,      -- Chromatic Mutation
    23171,      -- Time Stop (Brood Affliction: Bronze)
    22667,      -- Shadow Command
    23603,      -- Wild Polymorph
    23182,      -- Mark of Frost
    25043,      -- Aura of Nature
    24811,      -- Draw Spirit
    25806,      -- Creature of Nightmare
    6253,       -- Backhand
    6466,       -- Axe Toss
    8242,       -- Shield Slam
    8285,       -- Rampage
    6524,       -- Ground Tremor
    6607,       -- Lash
    7399,       -- Terrify
    8150,       -- Thundercrack
    11020,      -- Petrify
    11641,      -- Hex
    17307,      -- Knockout
    16075,      -- Throw Axe
    16104,      -- Crystallize
    11836,      -- Freeze Solid
    29419,      -- Flash Bomb
    6304,       -- Rhahk'Zor Slam
    6435,       -- Smite Slam
    6432,       -- Smite Stomp
    228,        -- Polymorph: Chicken
    8040,       -- Druid's Slumber
    7967,       -- Naralex's Nightmare
    7139,       -- Fel Stomp
    7621,       -- Arugal's Curse
    7803,       -- Thundershock
    7074,       -- Screams of the Past
    8281,       -- Sonic Burst
    8359,       -- Left for Dead
    9256,       -- Deep Sleep
    12946,      -- Putrid Stench
    3636,       -- Crystalline Slumber
    10093,      -- Harsh Winds
    21808,      -- Summon Shardlings
    21869,      -- Repulsive Gaze
    12888,      -- Cause Insanity
    12480,      -- Hex of Jammal'an
    12890,      -- Deep Slumber
    25774,      -- Mind Shatter
    15471,      -- Enveloping Web
    3609,       -- Paralyzing Poison
    17492,      -- Hand of Thaurissan
    14870,      -- Drunken Stupor
    13902,      -- Fist of Ragnaros
    6945,       -- Chest Pains
    3551,       -- Skull Crack
    15618,      -- Snap Kick
    16508,      -- Intimidating Roar
    16497,      -- Stun Bomb
    17405,      -- Domination
    16798,      -- Enchanting Lullaby
    12734,      -- Ground Smash
    17293,      -- Burning Winds
    16869,      -- Ice Tomb
    22856,      -- Ice Lock
    16838,      -- Banshee Shriek
}

C_Timer.After(11, function()
    for i = 1, #crowdControls do
        local name = GetSpellInfo(crowdControls[i])
        if name then
            ClassicCastbars.crowdControls[name] = 1
        end
    end
    crowdControls = nil
end)

-- Skip pushback calculation for these spells since they
-- have chance to ignore pushback when talented, or is always immune.
ClassicCastbars.pushbackBlacklist = {
    [GetSpellInfo(1064)] = 1,       -- Chain Heal
    [GetSpellInfo(25357)] = 1,      -- Healing Wave
    [GetSpellInfo(8004)] = 1,       -- Lesser Healing Wave
    [GetSpellInfo(2061)] = 1,       -- Flash Heal
    [GetSpellInfo(2054)] = 1,       -- Heal
    [GetSpellInfo(2050)] = 1,       -- Lesser Heal
    [GetSpellInfo(596)] = 1,        -- Prayer of Healing
    [GetSpellInfo(2060)] = 1,       -- Greater Heal
    [GetSpellInfo(19750)] = 1,      -- Flash of Light
    [GetSpellInfo(635)] = 1,        -- Holy Light
    -- Druid heals are afaik many times not talented so ignoring them for now

    [GetSpellInfo(4068)] = 1,       -- Iron Grenade
    [GetSpellInfo(19769)] = 1,      -- Thorium Grenade
    [GetSpellInfo(13278)] = 1,      -- Gnomish Death Ray
    [GetSpellInfo(20589)] = 1,      -- Escape Artist
}

-- Casts that should be stopped on damage received
ClassicCastbars.stopCastOnDamageList = {
    [GetSpellInfo(8690)] = 1, -- Hearthstone
    [GetSpellInfo(5784)] = 1, -- Summon Felsteed
    [GetSpellInfo(23161)] = 1, -- Summon Dreadsteed
    [GetSpellInfo(13819)] = 1, -- Summon Warhorse
    [GetSpellInfo(23214)] = 1, -- Summon Charger
    [GetSpellInfo(2006)] = 1, -- Resurrection
    [GetSpellInfo(2008)] = 1, -- Ancestral Spirit
    [GetSpellInfo(7328)] = 1, -- Redemption
    [GetSpellInfo(22999)] = 1, -- Defibrillate
    [GetSpellInfo(3565)] = 1, -- Teleport: Darnassus
    [GetSpellInfo(3562)] = 1, -- Teleport: Ironforge
    [GetSpellInfo(18960)] = 1, -- Teleport: Moonglade
    [GetSpellInfo(3567)] = 1, -- Teleport: Orgrimmar
    [GetSpellInfo(3561)] = 1, -- Teleport: Stormwind
    [GetSpellInfo(3566)] = 1, -- Teleport: Thunder Bluff
    [GetSpellInfo(3563)] = 1, -- Teleport: Undercity
    [GetSpellInfo(556)] = 1, -- Astrall Recall
    -- First Aid not included here since we track aura removed
}

-- Player spells that shouldn't be stopped on movement
ClassicCastbars.castStopBlacklist = {
    [GetSpellInfo(4068)] = 1,       -- Iron Grenade
    [GetSpellInfo(19769)] = 1,      -- Thorium Grenade
    [GetSpellInfo(13808)] = 1,      -- M73 Frag Grenade
    [GetSpellInfo(6405)] = 1,       -- Furgbolg Form
}

-- Spells that can't be slowed or speed up
ClassicCastbars.unaffectedCastModsSpells = {
    -- Player Spells
    [11605] = 1, -- Slam
    [6651] = 1, -- Instant Toxin
    [1842] = 1, -- Disarm Trap
    [6461] = 1, -- Pick Lock
    [20904] = 1, -- Aimed Shot
    [2641] = 1, -- Dismiss Pet
    [2480] = 1, -- Shoot Bow
    [7918] = 1, -- Shoot Gun
    [20549] = 1, -- War Stomp
    [20589] = 1, -- Escape Artist
    [22027] = 1, -- Remove Insignia
    [6510] = 1, -- Blinding Powder
    [7355] = 1, -- Stuck

    -- NPCs and Others
    [2835] = 1, -- Deadly Poison
    [3131] = 1, -- Frost Breath
    [15664] = 1, -- Venom Spit
    [7068] = 1, -- Veil of Shadow
    [16247] = 1, -- Curse of Thorns
    [14030] = 1, -- Hooked Net
    [20716] = 1, -- Sand Breath
    [8275] = 1, -- Poisoned Shot
    [1980] = 1, -- Bombard
    [3015] = 1, -- Bombard II
    [1536] = 1, -- Longshot II
    [3007] = 1, -- Longshot III
    [1540] = 1, -- Volley
    [3013] = 1, -- Volley II
    [4164] = 1, -- Throw Rock
    [4165] = 1, -- Throw Rock II
    [3537] = 1, -- Minions of Malathrom
    [5567] = 1, -- Miring Mud
    [28352] = 1, -- Breath of Sargeras
    [7106] = 1, -- Dark Restore
    [4075] = 1, -- Large Seaforium Charge
    [5106] = 1, -- Crystal Flash
    [22979] = 1, -- Shadow Flame
    [3611] = 1, -- Minion of Morganth
    [27794] = 1, -- Cleave
    [25247] = 1, -- Longsight
    [5208] = 1, -- Poisoned Harpoon
    [14532] = 1, -- Creeper Venom
    [3132] = 1, -- Chilling Breath
    [3650] = 1, -- Sling Mud
    [3651] = 1, -- Shield of Reflection
    [3143] = 1, -- Glacial Roar
    [6296] = 1, -- Enchant: Fiery Blaze
    [24194] = 1, -- Uther's Tribute
    [7364] = 1, -- Light Torch
    [12684] = 1, -- Kadrak's Flag
    [7919] = 1, -- Shoot Crossbow
    [6907] = 1, -- Diseased Slime
    [3204] = 1, -- Sapper Explode
    [26234] = 1, -- Submerge Visual
    [26063] = 1, -- Ouro Submerge Visual
    [6925] = 1, -- Gift of the Xavian
    [7951] = 1, -- Toxic Spit
    [24195] = 1, -- Grom's Tribute
    [16554] = 1, -- Toxic Bolt
    [15495] = 1, -- Explosive Shot
    [6530] = 1, -- Sling Dirt
    [26072] = 1, -- Dust Cloud
    [5514] = 1, -- Darken Vision
    [11016] = 1, -- Soul Bite
    [21050] = 1, -- Melodious Rapture
    [4520] = 1, -- Wide Sweep
    [4526] = 1, -- Mass Dispell
    [6576] = 1, -- Intimidating Growl
    [20627] = 1, -- Lightning Breath
    [25793] = 1, -- Demon Summoning Torch
    [23254] = 1, -- Redeeming the Soul
    [18711] = 1, -- Forging
    [12198] = 1, -- Marksman Hit
    [8153] = 1, -- Owl Form
    [6626] = 1, -- Set NG-5 Charge (Blue)
    [6630] = 1, -- Set NG-5 Charge (Red)
    [30081] = 1, -- Retching Plague
    [6656] = 1, -- Remote Detonate
    [10254] = 1, -- Stone Dwarf Awaken Visual
    [3359] = 1, -- Drink Potion
    [17618] = 1, -- Summon Risen Lackey
    [8286] = 1, -- Summon Boar Spirit
    [17235] = 1, -- Raise Undead Scarab
    [8386] = 1, -- Attacking
    [28311] = 1, -- Slime Bolt
    [1698] = 1, -- Shockwave
    [23008] = 1, -- Powerful Seaforium Charge
    [6951] = 1, -- Decayed Strength
    [28732] = 1, -- Widow's Embrace
    [28995] = 1, -- Stoneskin
    [24706] = 1, -- Toss Stink Bomb
    [6257] = 1, -- Torch Toss
    [7359] = 1, -- Bright Campfire
    [16590] = 1, -- Summon Zombie
    [9612] = 1, -- Ink Spray
    [3436] = 1, -- Wandering Plague
    [9636] = 1, -- Summon Swamp Spirit
    [17204] = 1, -- Summon Skeleton
    [7896] = 1, -- Exploding Shot
    [23392] = 1, -- Boulder
    [7920] = 1, -- Mebok Smart Drink
    [8682] = 1, -- Fake Shot
    [28614] = 1, -- Pointy Spike
    [8016] = 1, -- Spirit Decay
    [26102] = 1, -- Sand Blast
    [3477] = 1, -- Spirit Steal
    [5395] = 1, -- Death Capsule
    [5159] = 1, -- Melt Ore
    [5403] = 1, -- Crash of Waves
    [8256] = 1, -- Lethal Toxin
    [6441] = 1, -- Explosive Shells
    [10850] = 1, -- Powerful Smelling Salts
    [3488] = 1, -- Felstrom Resurrection
    [10346] = 1, -- Machine Gun
    [12740] = 1, -- Summon Infernal Servant
    [6469] = 1, -- Skeletal Miner Explode
    [11397] = 1, -- Diseased Shot
    [4950] = 1, -- Summon Helcular's Puppets
    [8363] = 1, -- Parasite
    [16531] = 1, -- Summon Frail Skeleton
    [16072] = 1, -- Purify and Place Food
    [20629] = 1, -- Corrosive Venom Spit
    [28615] = 1, -- Spike Volley
    [19566] = 1, -- Salt Shaker
    [7901] = 1, -- Decayed Agility
    [7054] = 1, -- Forsaken Skills
    [24189] = 1, -- Force Punch
}

-- Addon Savedvariables
ClassicCastbars.defaultConfig = {
    version = "17", -- settings version
    pushbackDetect = true,
    locale = GetLocale(),

    nameplate = {
        enabled = true,
        width = 102,
        height = 6,
        iconSize = 16,
        showCastInfoOnly = false,
        showTimer = true,
        showIcon = true,
        autoPosition = true,
        castFont = _G.STANDARD_TEXT_FONT,
        castFontSize = 8,
        castStatusBar = "Interface\\Addons\\_ShiGuang\\Media\\normTex",
        castBorder = "Interface\\Tooltips\\ChatBubble-Backdrop",
        hideIconBorder = false,
        position = { "CENTER", -1, -12 },
        iconPositionX = -3,
        iconPositionY = 0,
        borderColor = { 1, 0.8, 0, 1 },
        statusColor = { 1, 0.7, 0, 1 },
        statusColorFailed = { 1, 0, 0 },
        statusColorChannel = { 0, 1, 0, 1 },
        textColor = { 1, 1, 1, 1 },
        textPositionX = 6,
        textPositionY = -1,
        frameLevel = 10,
        statusBackgroundColor = { 0, 0, 0, 0.535 },
    },

    target = {
        enabled = true,
        width = 150,
        height = 15,
        iconSize = 16,
        showCastInfoOnly = false,
        showTimer = false,
        showIcon = true,
        autoPosition = true,
        castFont = _G.STANDARD_TEXT_FONT,
        castFontSize = 10,
        castStatusBar = "Interface\\TargetingFrame\\UI-StatusBar",
        castBorder = "Interface\\CastingBar\\UI-CastingBar-Border-Small",
        hideIconBorder = false,
        position = { "CENTER", -18, -87 },
        iconPositionX = -5,
        iconPositionY = 0,
        borderColor = { 1, 1, 1, 1 },
        statusColor = { 1, 0.7, 0, 1 },
        statusColorFailed = { 1, 0, 0 },
        statusColorChannel = { 0, 1, 0, 1 },
        textColor = { 1, 1, 1, 1 },
        textPositionX = 6,
        textPositionY = -1,
        frameLevel = 10,
        statusBackgroundColor = { 0, 0, 0, 0.535 },
    },

    focus = {
        enabled = true,
        width = 150,
        height = 15,
        iconSize = 16,
        showCastInfoOnly = false,
        showTimer = false,
        showIcon = true,
        autoPosition = false,
        castFont = _G.STANDARD_TEXT_FONT,
        castFontSize = 10,
        castStatusBar = "Interface\\TargetingFrame\\UI-StatusBar",
        castBorder = "Interface\\CastingBar\\UI-CastingBar-Border-Small",
        hideIconBorder = false,
        position = { "TOPLEFT", 275, -260 },
        iconPositionX = -5,
        iconPositionY = 0,
        borderColor = { 1, 1, 1, 1 },
        statusColor = { 1, 0.7, 0, 1 },
        statusColorFailed = { 1, 0, 0 },
        statusColorChannel = { 0, 1, 0, 1 },
        textColor = { 1, 1, 1, 1 },
        textPositionX = 6,
        textPositionY = -1,
        frameLevel = 10,
        statusBackgroundColor = { 0, 0, 0, 0.535 },
    },

    party = {
        enabled = true,
        width = 120,
        height = 12,
        iconSize = 16,
        showCastInfoOnly = false,
        showTimer = false,
        showIcon = true,
        autoPosition = false,
        castFont = _G.STANDARD_TEXT_FONT,
        castFontSize = 9,
        castStatusBar = "Interface\\Addons\\_ShiGuang\\Media\\normTex",
        castBorder = "Interface\\Tooltips\\ChatBubble-Backdrop",
        hideIconBorder = false,
        position = { "CENTER", -143.5, -5 },
        iconPositionX = -5,
        iconPositionY = 0,
        borderColor = { 1, 1, 1, 1 },
        statusColor = { 1, 0.7, 0, 1 },
        statusColorFailed = { 1, 0, 0 },
        statusColorChannel = { 0, 1, 0, 1 },
        textColor = { 1, 1, 1, 1 },
        textPositionX = 0,
        textPositionY = 0,
        frameLevel = 10,
        statusBackgroundColor = { 0, 0, 0, 0.535 },
    },

    player = {
        enabled = false,
        width = 190,
        height = 19,
        iconSize = 16,
        showCastInfoOnly = false,
        showTimer = false,
        showIcon = true,
        autoPosition = true,
        castFont = _G.STANDARD_TEXT_FONT,
        castFontSize = 12,
        castStatusBar = "Interface\\TargetingFrame\\UI-StatusBar",
        castBorder = "Interface\\CastingBar\\UI-CastingBar-Border",
        hideIconBorder = false,
        position = { "CENTER", -18, -87 },
        iconPositionX = -5,
        iconPositionY = 0,
        borderColor = { 1, 1, 1, 1 },
        statusColor = { 1, 0.7, 0, 1 },
        statusColorFailed = { 1, 0, 0 },
        statusColorChannel = { 0, 1, 0, 1 },
        textColor = { 1, 1, 1, 1 },
        textPositionX = 0,
        textPositionY = 0,
        frameLevel = 10,
        statusBackgroundColor = { 0, 0, 0, 0.535 },
    },
}

local PoolManager = ClassicCastbars.PoolManager

local addon = CreateFrame("Frame")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function(self, event, ...)
    return self[event](self, ...)
end)

local activeGUIDs = {}
local activeTimers = {} -- active cast data
local activeFrames = {}
local npcCastTimeCacheStart = {}
local npcCastTimeCache = {}

addon.AnchorManager = ClassicCastbars.AnchorManager
addon.defaultConfig = ClassicCastbars.defaultConfig
addon.activeFrames = activeFrames
addon.activeTimers = activeTimers
--ClassicCastbars.addon = addon
--ClassicCastbars = addon -- global ref for ClassicCastbars_Options

-- upvalues for speed
local gsub = _G.string.gsub
local strfind = _G.string.find
local pairs = _G.pairs
local UnitGUID = _G.UnitGUID
local UnitAura = _G.UnitAura
local UnitClass = _G.UnitClass
local GetSpellTexture = _G.GetSpellTexture
local GetSpellInfo = _G.GetSpellInfo
local CombatLogGetCurrentEventInfo = _G.CombatLogGetCurrentEventInfo
local GetTime = _G.GetTime
local max = _G.math.max
local abs = _G.math.abs
local next = _G.next
local floor = _G.math.floor
local GetUnitSpeed = _G.GetUnitSpeed
local CastingInfo = _G.CastingInfo
local ChannelInfo = _G.ChannelInfo
local castTimeIncreases = ClassicCastbars.castTimeIncreases
local pushbackBlacklist = ClassicCastbars.pushbackBlacklist
local unaffectedCastModsSpells = ClassicCastbars.unaffectedCastModsSpells

local BARKSKIN = GetSpellInfo(22812)
local FOCUSED_CASTING = GetSpellInfo(14743)
local NATURES_GRACE = GetSpellInfo(16886)
local MIND_QUICKENING = GetSpellInfo(23723)
local BLINDING_LIGHT = GetSpellInfo(23733)
local BERSERKING = GetSpellInfo(20554)

function addon:GetUnitType(unitID)
    local unit = gsub(unitID or "", "%d", "")
    if unit == "nameplate-testmode" then
        unit = "nameplate"
    elseif unit == "party-testmode" then
        unit = "party"
    end

    return unit
end

function addon:CheckCastModifier(unitID, cast)
    if unitID == "focus" then return end
    if not self.db.pushbackDetect or not cast then return end
    if cast.unitGUID == self.PLAYER_GUID then return end -- modifiers already taken into account with CastingInfo()
    if unaffectedCastModsSpells[cast.spellID] then return end

    -- Debuffs
    if not cast.isChanneled and not cast.hasCastSlowModified and not cast.skipCastSlowModifier then
        for i = 1, 16 do
            local _, _, _, _, _, _, _, _, _, spellID = UnitAura(unitID, i, "HARMFUL")
            if not spellID then break end -- no more debuffs

            local slow = castTimeIncreases[spellID]
            if slow then -- note: multiple slows stack
                cast.endTime = cast.timeStart + (cast.endTime - cast.timeStart) * ((slow / 100) + 1)
                cast.hasCastSlowModified = true
            end
        end
    end

    -- Buffs
    local _, className = UnitClass(unitID)
    local _, raceFile = UnitRace(unitID)
    if className == "DRUID" or className == "PRIEST" or className == "MAGE" or className == "PALADIN" or raceFile == "Troll" then
        local libCD = LibStub and LibStub("LibClassicDurations", true)
        local libCDEnemyBuffs = libCD and libCD.enableEnemyBuffTracking

        for i = 1, 32 do
            local name
            if not libCDEnemyBuffs then
                name = UnitAura(unitID, i, "HELPFUL")
            else
                -- if LibClassicDurations happens to be loaded by some other addon, use it
                -- to get enemy buff data
                name = libCD.UnitAuraWithBuffs(unitID, i, "HELPFUL")
            end
            if not name then break end -- no more buffs

            if name == BARKSKIN and not cast.hasBarkskinModifier then
                cast.endTime = cast.endTime + 1
                cast.hasBarkskinModifier = true
            elseif name == NATURES_GRACE and not cast.hasNaturesGraceModifier and not cast.isChanneled then
                cast.endTime = cast.endTime - 0.5
                cast.hasNaturesGraceModifier = true
            elseif (name == MIND_QUICKENING or name == BLINDING_LIGHT) and not cast.hasSpeedModifier and not cast.isChanneled then
                cast.endTime = cast.endTime - ((cast.endTime - cast.timeStart) * 33 / 100)
                cast.hasSpeedModifier = true
            elseif name == BERSERKING and not cast.hasBerserkingModifier and not cast.isChanneled then -- put this seperate as it can stack with other modifiers
                cast.endTime = cast.endTime - ((cast.endTime - cast.timeStart) * 0.1)
                cast.hasBerserkingModifier = true
            elseif name == FOCUSED_CASTING then
                cast.hasFocusedCastingModifier = true
            end
        end
    end
end

function addon:StartCast(unitGUID, unitID)
    local cast = activeTimers[unitGUID]
    if not cast then return end

    local castbar = self:GetCastbarFrame(unitID)
    if not castbar then return end

    castbar._data = cast -- set ref to current cast data
    self:DisplayCastbar(castbar, unitID)
    self:CheckCastModifier(unitID, cast)
end

function addon:StopCast(unitID, noFadeOut)
    local castbar = activeFrames[unitID]
    if not castbar then return end

    if not castbar.isTesting then
        self:HideCastbar(castbar, unitID, noFadeOut)
    end

    castbar._data = nil
end

function addon:StartAllCasts(unitGUID)
    if not activeTimers[unitGUID] then return end

    for unitID, guid in pairs(activeGUIDs) do
        if guid == unitGUID then
            self:StartCast(guid, unitID)
        end
    end
end

function addon:StopAllCasts(unitGUID, noFadeOut)
    for unitID, guid in pairs(activeGUIDs) do
        if guid == unitGUID then
            self:StopCast(unitID, noFadeOut)
        end
    end
end

-- Store or refresh new cast data for unit, and start castbar(s)
function addon:StoreCast(unitGUID, spellName, spellID, iconTexturePath, castTime, isPlayer, isChanneled)
    local currTime = GetTime()

    if not activeTimers[unitGUID] then
        activeTimers[unitGUID] = {}
    end

    local cast = activeTimers[unitGUID]
    cast.spellName = spellName
    cast.spellID = spellID
    cast.icon = iconTexturePath
    cast.maxValue = castTime / 1000
    cast.endTime = currTime + (castTime / 1000)
    cast.isChanneled = isChanneled
    cast.unitGUID = unitGUID
    cast.timeStart = currTime
    cast.isPlayer = isPlayer
    cast.hasCastSlowModified = nil -- just nil previous values to avoid overhead of wiping table
    cast.hasBarkskinModifier = nil
    cast.hasNaturesGraceModifier = nil
    cast.hasFocusedCastingModifier = nil
    cast.hasSpeedModifier = nil
    cast.hasBerserkingModifier = nil
    cast.skipCastSlowModifier = nil
    cast.pushbackValue = nil
    cast.isInterrupted = nil
    cast.isCastComplete = nil
    cast.isFailed = nil

    self:StartAllCasts(unitGUID)
end

-- Delete cast data for unit, and stop any active castbars
function addon:DeleteCast(unitGUID, isInterrupted, skipDeleteCache, isCastComplete, noFadeOut)
    if not unitGUID then return end

    local cast = activeTimers[unitGUID]
    if cast then
        cast.isInterrupted = isInterrupted -- just so we can avoid passing it as an arg for every function call
        cast.isCastComplete = isCastComplete -- SPELL_CAST_SUCCESS detected
        self:StopAllCasts(unitGUID, noFadeOut)
        activeTimers[unitGUID] = nil
    end

    -- Weak tables doesn't work with literal values so we need to manually handle memory for this cache :/
    if not skipDeleteCache and npcCastTimeCacheStart[unitGUID] then
        npcCastTimeCacheStart[unitGUID] = nil
    end
end

function addon:CastPushback(unitGUID)
    if not self.db.pushbackDetect then return end
    local cast = activeTimers[unitGUID]
    if not cast or cast.hasBarkskinModifier or cast.hasFocusedCastingModifier then return end
    if pushbackBlacklist[cast.spellName] then return end

    if not cast.isChanneled then
        -- https://wow.gamepedia.com/index.php?title=Interrupt&oldid=305918
        cast.pushbackValue = cast.pushbackValue or 1.0
        cast.maxValue = cast.maxValue + cast.pushbackValue
        cast.endTime = cast.endTime + cast.pushbackValue
        cast.pushbackValue = max(cast.pushbackValue - 0.5, 0.2)
    else
        -- channels are reduced by 25% per hit afaik
        cast.maxValue = cast.maxValue - (cast.maxValue * 25) / 100
        cast.endTime = cast.endTime - (cast.maxValue * 25) / 100
    end
end

SLASH_CCFOCUS1 = "/focus"
SLASH_CCFOCUS2 = "/castbarfocus"
SlashCmdList["CCFOCUS"] = function(msg)
    local unitID = msg == "mouseover" and "mouseover" or "target"
    local tarGUID = UnitGUID(unitID)
    if tarGUID then
        activeGUIDs.focus = tarGUID
        addon:StopCast("focus", true)
        addon:StartCast(tarGUID, "focus")
        addon:SetFocusDisplay(UnitName(unitID), unitID)
    else
        SlashCmdList["CCFOCUSCLEAR"]()
    end
end

SLASH_CCFOCUSCLEAR1 = "/clearfocus"
SlashCmdList["CCFOCUSCLEAR"] = function()
    if activeGUIDs.focus then
        activeGUIDs.focus = nil
        addon:StopCast("focus", true)
        addon:SetFocusDisplay(nil)
    end
end

local function GetSpellCastInfo(spellID)
    local _, _, icon, castTime = GetSpellInfo(spellID)
    if not castTime then return end

    if not unaffectedCastModsSpells[spellID] then
        local _, _, _, hCastTime = GetSpellInfo(8690) -- Hearthstone, normal cast time 10s
        if hCastTime and hCastTime ~= 10000 and hCastTime ~= 0 then -- If current cast time is not 10s it means the player has a casting speed modifier debuff applied on himself.
            -- Since the return values by GetSpellInfo() are affected by the modifier, we need to remove so it doesn't give modified casttimes for other peoples casts.
            return floor(castTime * 10000 / hCastTime), icon
        end
    end

    return castTime, icon
end

function addon:ToggleUnitEvents(shouldReset)
    if MaoRUIPerDB["Nameplate"]["TargetClassicCastbars"] then
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        if self.db.target.autoPosition then
            self:RegisterUnitEvent("UNIT_AURA", "target")
        end
    else
        self:UnregisterEvent("PLAYER_TARGET_CHANGED")
        self:UnregisterEvent("UNIT_AURA")
    end

    if MaoRUIPerDB["Nameplate"]["ClassicCastbars"] then
        self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    else
        self:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
        self:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
    end

    if self.db.party.enabled then
        self:RegisterEvent("GROUP_ROSTER_UPDATE")
        self:RegisterEvent("GROUP_JOINED")
    else
        self:UnregisterEvent("GROUP_ROSTER_UPDATE")
        self:UnregisterEvent("GROUP_JOINED")
    end

    if shouldReset then
        self:PLAYER_ENTERING_WORLD() -- wipe all data
    end
end

function addon:PLAYER_ENTERING_WORLD(isInitialLogin)
    if isInitialLogin then return end

    -- Reset all data on loading screens
    wipe(activeGUIDs)
    wipe(activeTimers)
    wipe(activeFrames)
    PoolManager:GetFramePool():ReleaseAll() -- also wipes castbar._data
    self:SetFocusDisplay(nil)

    if self.db.party.enabled and IsInGroup() then
        self:GROUP_ROSTER_UPDATE()
    end
end

function addon:ZONE_CHANGED_NEW_AREA()
    wipe(npcCastTimeCacheStart)
    wipe(npcCastTimeCache)
end

-- Copies table values from src to dst if they don't exist in dst
local function CopyDefaults(src, dst)
    if type(src) ~= "table" then return {} end
    if type(dst) ~= "table" then dst = {} end

    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif type(v) ~= type(dst[k]) then
            dst[k] = v
        end
    end

    return dst
end

function addon:PLAYER_LOGIN()
    ClassicCastbarsDB = ClassicCastbarsDB or {}

    -- Copy any settings from defaults if they don't exist in current profile
    self.db = CopyDefaults(ClassicCastbars.defaultConfig, ClassicCastbarsDB)
    self.db.version = ClassicCastbars.defaultConfig.version

    -- Reset fonts on game locale switched (fonts only works for certain locales)
    if self.db.locale ~= GetLocale() then
        self.db.locale = GetLocale()
        self.db.target.castFont = _G.STANDARD_TEXT_FONT
        self.db.nameplate.castFont = _G.STANDARD_TEXT_FONT
    end

    -- config is not needed anymore if options are not loaded
    if not IsAddOnLoaded("ClassicCastbars_Options") then
        self.defaultConfig = nil
        ClassicCastbars.defaultConfig = nil
    end

    if self.db.player.enabled then
        self:SkinPlayerCastbar()
    end

    self.PLAYER_GUID = UnitGUID("player")
    self:ToggleUnitEvents()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:UnregisterEvent("PLAYER_LOGIN")
    self.PLAYER_LOGIN = nil
end

local auraRows = 0
function addon:UNIT_AURA()
    if not self.db.target.autoPosition then return end
    if auraRows == TargetFrame.auraRows then return end
    auraRows = TargetFrame.auraRows

    if activeFrames.target and activeGUIDs.target then
        local parentFrame = self.AnchorManager:GetAnchor("target")
        if parentFrame then
            self:SetTargetCastbarPosition(activeFrames.target, parentFrame)
        end
    end
end

-- Bind unitIDs to unitGUIDs so we can efficiently get unitIDs in CLEU events
function addon:PLAYER_TARGET_CHANGED()
    activeGUIDs.target = UnitGUID("target") or nil

    self:StopCast("target", true) -- always hide previous target's castbar
    self:StartCast(activeGUIDs.target, "target") -- Show castbar again if available
end

function addon:NAME_PLATE_UNIT_ADDED(namePlateUnitToken)
    local unitGUID = UnitGUID(namePlateUnitToken)
    activeGUIDs[namePlateUnitToken] = unitGUID

    self:StartCast(unitGUID, namePlateUnitToken)
end

function addon:NAME_PLATE_UNIT_REMOVED(namePlateUnitToken)
    activeGUIDs[namePlateUnitToken] = nil

    -- Release frame, but do not delete cast data
    local castbar = activeFrames[namePlateUnitToken]
    if castbar then
        PoolManager:ReleaseFrame(castbar)
        activeFrames[namePlateUnitToken] = nil
    end
end

function addon:GROUP_ROSTER_UPDATE()
    for i = 1, 5 do
        local unitID = "party"..i
        activeGUIDs[unitID] = UnitGUID(unitID) or nil

        if activeGUIDs[unitID] then
            self:StopCast(unitID, true)
        else
            local castbar = activeFrames[unitID]
            if castbar then
                PoolManager:ReleaseFrame(castbar)
                activeFrames[unitID] = nil
            end
        end
    end
end
addon.GROUP_JOINED = addon.GROUP_ROSTER_UPDATE

-- Upvalues for combat log events
local bit_band = _G.bit.band
local COMBATLOG_OBJECT_CONTROL_PLAYER = _G.COMBATLOG_OBJECT_CONTROL_PLAYER
local COMBATLOG_OBJECT_TYPE_PLAYER = _G.COMBATLOG_OBJECT_TYPE_PLAYER
local channeledSpells = ClassicCastbars.channeledSpells
local castTimeTalentDecreases = ClassicCastbars.castTimeTalentDecreases
local crowdControls = ClassicCastbars.crowdControls
local castedSpells = ClassicCastbars.castedSpells
local stopCastOnDamageList = ClassicCastbars.stopCastOnDamageList
local ARCANE_MISSILES = GetSpellInfo(5143)
local ARCANE_MISSILE = GetSpellInfo(7268)

function addon:COMBAT_LOG_EVENT_UNFILTERED()
    local _, eventType, _, srcGUID, srcName, srcFlags, _, dstGUID, _, dstFlags, _, _, spellName = CombatLogGetCurrentEventInfo()

    if eventType == "SPELL_CAST_START" then
        local spellID = castedSpells[spellName]
        if not spellID then return end

        local castTime, icon = GetSpellCastInfo(spellID)
        if not castTime then return end

        -- is player or player pet or mind controlled
        local isPlayer = bit_band(srcFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) > 0

        if srcGUID ~= self.PLAYER_GUID then
            if isPlayer then
                -- Use hardcoded talent reduced cast time for certain player spells
                local reducedTime = castTimeTalentDecreases[spellName]
                if reducedTime then
                    castTime = reducedTime
                end
            else
                local cachedTime = npcCastTimeCache[srcName .. spellName]
                if cachedTime then
                    -- Use cached time stored from earlier sightings for NPCs.
                    -- This is because mobs have various cast times, e.g a lvl 20 mob casting Frostbolt might have
                    -- 3.5 cast time but another lvl 40 mob might have 2.5 cast time instead for Frostbolt.
                    castTime = cachedTime
                else
                    npcCastTimeCacheStart[srcGUID] = GetTime()
                end
            end
        else
            local _, _, _, startTime, endTime = CastingInfo()
            if endTime and startTime then
                castTime = endTime - startTime
            end
        end

        -- Note: using return here will make the next function (StoreCast) reuse the current stack frame which is slightly more performant
        return self:StoreCast(srcGUID, spellName, spellID, icon, castTime, isPlayer)
    elseif eventType == "SPELL_CAST_SUCCESS" then
        local channelCast = channeledSpells[spellName]
        local spellID = castedSpells[spellName]
        if not channelCast and not spellID then
            -- Stop cast on new ability used while castbar is shown
            if activeTimers[srcGUID] and GetTime() - activeTimers[srcGUID].timeStart > 0.25 then
                return self:StopAllCasts(srcGUID)
            end

            return -- not a cast
        end

        local isPlayer = bit_band(srcFlags, COMBATLOG_OBJECT_CONTROL_PLAYER) > 0

        -- Auto correct cast times for mobs
        if not isPlayer and not channelCast then
            if not strfind(srcGUID, "Player-") then -- incase player is mind controlled by an NPC
                local cachedTime = npcCastTimeCache[srcName .. spellName]
                if not cachedTime then
                    local cast = activeTimers[srcGUID]
                    if not cast or (cast and not cast.hasCastSlowModified and not cast.hasSpeedModifier and not cast.hasBerserkingModifier) then
                        local restoredStartTime = npcCastTimeCacheStart[srcGUID]
                        if restoredStartTime then
                            local castTime = (GetTime() - restoredStartTime) * 1000
                            local origCastTime = 0
                            if spellID then
                                local cTime = GetSpellCastInfo(spellID)
                                origCastTime = cTime or 0
                            end

                            local castTimeDiff = abs(castTime - origCastTime)
                            if castTimeDiff <= 4000 and castTimeDiff > 250 then -- heavy lag might affect this so only store time if the diff isn't too big
                                npcCastTimeCache[srcName .. spellName] = castTime
                            end
                        end
                    end
                end
            end
        end

        -- Channeled spells are started on SPELL_CAST_SUCCESS instead of stopped
        -- Also there's no castTime returned from GetSpellInfo for channeled spells so we need to get it from our own list
        if channelCast then
            -- Arcane Missiles triggers this event for every tick so ignore after first tick has been detected
            if (spellName == ARCANE_MISSILES or spellName == ARCANE_MISSILE) and activeTimers[srcGUID] then
                if activeTimers[srcGUID].spellName == ARCANE_MISSILES or activeTimers[srcGUID].spellName == ARCANE_MISSILE then return end
            end

            return self:StoreCast(srcGUID, spellName, spellID, GetSpellTexture(spellID), channelCast, isPlayer, true)
        end

        -- non-channeled spell, finish it.
        -- We also check the expiration timer in OnUpdate script just incase this event doesn't trigger when i.e unit is no longer in range.
        return self:DeleteCast(srcGUID, nil, nil, true)
    elseif eventType == "SPELL_AURA_APPLIED" then
        if crowdControls[spellName] and activeTimers[dstGUID] then
            -- Aura that interrupts cast was applied
            activeTimers[dstGUID].isFailed = true
            return self:DeleteCast(dstGUID)
        elseif castTimeIncreases[spellName] and activeTimers[dstGUID] then
            -- Cast modifiers doesnt modify already active casts, only the next time the player casts
            activeTimers[dstGUID].skipCastSlowModifier = true
        end
    elseif eventType == "SPELL_AURA_REMOVED" then
        -- Channeled spells has no SPELL_CAST_* event for channel stop,
        -- so check if aura is gone instead since most channels has an aura effect.
        if channeledSpells[spellName] and srcGUID == dstGUID then
            return self:DeleteCast(srcGUID, nil, nil, true)
        end
    elseif eventType == "SPELL_CAST_FAILED" then
        local cast = activeTimers[srcGUID]
        if cast then
            if srcGUID == self.PLAYER_GUID then
                -- Spamming cast keybinding triggers SPELL_CAST_FAILED so check if actually casting or not for the player
                -- Using Arcane Missiles on a target that is currenly LoS also seem to trigger SPELL_CAST_FAILED for some reason...
                if not CastingInfo() and not ChannelInfo() then
                    if not cast.isChanneled then
                        cast.isFailed = true
                    end
                    return self:DeleteCast(srcGUID, nil, nil, cast.isChanneled) -- note: channels shows finish anim on cast failed
                end
            else
                if not cast.isChanneled then
                    cast.isFailed = true
                end
                return self:DeleteCast(srcGUID, nil, nil, cast.isChanneled)
            end
        end
    elseif eventType == "PARTY_KILL" or eventType == "UNIT_DIED" or eventType == "SPELL_INTERRUPT" then
        return self:DeleteCast(dstGUID, eventType == "SPELL_INTERRUPT")
    elseif eventType == "SWING_DAMAGE" or eventType == "ENVIRONMENTAL_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SPELL_DAMAGE" then
        if bit_band(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then -- is player, and not pet
            local cast = activeTimers[dstGUID]
            if cast then
                if stopCastOnDamageList[cast.spellName] and activeTimers[dstGUID] then
                    activeTimers[dstGUID].isFailed = true
                    return self:DeleteCast(dstGUID)
                end

                return self:CastPushback(dstGUID)
            end
        end
    end
end

local refresh = 0
local castStopBlacklist = ClassicCastbars.castStopBlacklist
addon:SetScript("OnUpdate", function(self, elapsed)
    if not next(activeTimers) then return end
    local currTime = GetTime()
    local pushbackEnabled = self.db.pushbackDetect

    refresh = refresh - elapsed
    if refresh < 0 then
        if next(activeGUIDs) then
            -- Check if unit is moving to stop castbar, thanks to Cordankos for this idea
            for unitID, unitGUID in pairs(activeGUIDs) do
                if unitID ~= "focus" then
                    local cast = activeTimers[unitGUID]
                    -- Only stop cast for players since some mobs runs while casting, also because
                    -- of lag we have to only stop it if the cast has been active for atleast 0.25 sec
                    if cast and cast.isPlayer and currTime - cast.timeStart > 0.25 then
                        if not castStopBlacklist[cast.spellName] and GetUnitSpeed(unitID) ~= 0 then
                            local castAlmostFinishied = ((currTime - cast.timeStart) > cast.maxValue - 0.1)
                            -- due to lag its possible that the cast is successfuly casted but still shows interrupted
                            -- unless we ignore the last few miliseconds here
                            if not castAlmostFinishied then
                                if not cast.isChanneled then
                                    cast.isFailed = true
                                end
                                self:DeleteCast(unitGUID, nil, nil, cast.isChanneled)
                            end
                        end
                    end
                end
            end
        end
        refresh = 0.1
    end

    -- Update all shown castbars in a single OnUpdate call
    for unit, castbar in pairs(activeFrames) do
        local cast = castbar._data
        if cast then
            local castTime = cast.endTime - currTime

            if (castTime > 0) then
                if not castbar.showCastInfoOnly then
                    local maxValue = cast.endTime - cast.timeStart
                    local value = currTime - cast.timeStart
                    if cast.isChanneled then -- inverse
                        value = maxValue - value
                    end

                    if pushbackEnabled then
                        -- maxValue is only updated dynamically when pushback detect is enabled
                        castbar:SetMinMaxValues(0, maxValue)
                    end

                    castbar:SetValue(value)
                    castbar.Timer:SetFormattedText("%.1f", castTime)
                    local sparkPosition = (value / maxValue) * castbar:GetWidth()
                    castbar.Spark:SetPoint("CENTER", castbar, "LEFT", sparkPosition, 0)
                end
            else
                -- slightly adjust color of the castbar when its not 100% sure if the cast is casted or failed
                -- (gotta put it here to run before fadeout anim)
                if not cast.isCastComplete and not cast.isInterrupted and not cast.isFailed then
                    castbar.Spark:SetAlpha(0)
                    if not cast.isChanneled then
                        local c = self.db[self:GetUnitType(unit)].statusColor
                        castbar:SetStatusBarColor(c[1], c[2] + 0.1, c[3], c[4])
                        castbar:SetMinMaxValues(0, 1)
                        castbar:SetValue(1)
                    else
                        castbar:SetValue(0)
                    end
                end

                -- Delete cast incase stop event wasn't detected in CLEU
                if castTime <= -0.25 then -- wait atleast 0.25s before deleting incase CLEU stop event is happening at same time
                    if cast.isChanneled and not cast.isCastComplete and not cast.isInterrupted and not cast.isFailed then
                        -- show finish animation on channels that doesnt have CLEU stop event
                        -- Note: channels always have finish animations on stop, even if it was an early stop
                        local skipFade = ((currTime - cast.timeStart) > cast.maxValue + 0.4) -- skips fade anim on castbar being RESHOWN if the cast is expired
                        self:DeleteCast(cast.unitGUID, false, true, true, skipFade)
                    else
                        local skipFade = ((currTime - cast.timeStart) > cast.maxValue + 0.25)
                        self:DeleteCast(cast.unitGUID, false, true, false, skipFade)
                    end
                end
            end
        end
    end
end)


local AnchorManager = ClassicCastbars.AnchorManager
local PoolManager = ClassicCastbars.PoolManager

--local addon = ClassicCastbars.addon
local activeFrames = addon.activeFrames
local strfind = _G.string.find
local unpack = _G.unpack
local min = _G.math.min
local max = _G.math.max
local ceil = _G.math.ceil
local InCombatLockdown = _G.InCombatLockdown

function addon:GetCastbarFrame(unitID)
    -- PoolManager:DebugInfo()
    if unitID == "player" then return CastingBarFrame end

    if activeFrames[unitID] then
        return activeFrames[unitID]
    end

    activeFrames[unitID] = PoolManager:AcquireFrame()

    return activeFrames[unitID]
end

function addon:SetTargetCastbarPosition(castbar, parentFrame)
    local auraRows = parentFrame.auraRows or 0

    if parentFrame.buffsOnTop or auraRows <= 1 then
        castbar:SetPoint("CENTER", parentFrame, -18, -75)
    else
        castbar:SetPoint("CENTER", parentFrame, -18, max(min(-75, -38.5 * auraRows), -150))
    end
end

function addon:SetCastbarIconAndText(castbar, cast, db)
    local spellName = cast.spellName

    if castbar.Text:GetText() ~= spellName then
        if cast.icon == 136235 then -- unknown texture
            cast.icon = 136243
        end
        castbar.Icon:SetTexture(cast.icon)
        castbar.Text:SetText(spellName)

        -- Move timer position depending on spellname length
        if db.showTimer then
            castbar.Timer:SetPoint("RIGHT", castbar, (spellName:len() >= 19) and 30 or -6, 0)
        end
    end
end

function addon:SetCastbarStyle(castbar, cast, db)
    castbar:SetSize(db.width, db.height)
    castbar.Timer:SetShown(db.showTimer)
    castbar:SetStatusBarTexture(db.castStatusBar)
    castbar:SetFrameLevel(db.frameLevel)

    if db.showCastInfoOnly then
        castbar.showCastInfoOnly = true
        castbar.Timer:SetText("")
        castbar:SetValue(0)
        castbar.Spark:SetAlpha(0)
    else
        castbar.Spark:SetAlpha(1)
        castbar.showCastInfoOnly = false
    end

    if db.hideIconBorder then
        castbar.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        castbar.Icon:SetTexCoord(0, 1, 0, 1)
    end

    castbar.Spark:SetHeight(db.height * 2.1)
    castbar.Icon:SetShown(db.showIcon)
    castbar.Icon:SetSize(db.iconSize, db.iconSize)
    castbar.Icon:SetPoint("LEFT", castbar, db.iconPositionX - db.iconSize, db.iconPositionY)
    castbar.Border:SetVertexColor(unpack(db.borderColor))

    castbar.Flash:ClearAllPoints()
    castbar.Flash:SetPoint("TOPLEFT", ceil(-db.width / 6.25), db.height-1)
    castbar.Flash:SetPoint("BOTTOMRIGHT", ceil(db.width / 6.25), -db.height-1)

    if db.castBorder == "Interface\\CastingBar\\UI-CastingBar-Border-Small" or db.castBorder == "Interface\\CastingBar\\UI-CastingBar-Border" then -- default border
        castbar.Border:SetAlpha(1)
        if castbar.BorderFrame then
            -- Hide LSM border frame if it exists
            castbar.BorderFrame:SetAlpha(0)
        end

        -- Update border to match castbar size
        local width, height = ceil(castbar:GetWidth() * 1.16), ceil(castbar:GetHeight() * 1.16)
        castbar.Border:ClearAllPoints()
        castbar.Border:SetPoint("TOPLEFT", width, height+1)
        castbar.Border:SetPoint("BOTTOMRIGHT", -width, -height)
    else
        -- Using border sat by LibSharedMedia
        self:SetLSMBorders(castbar, cast, db)
    end
end

local textureFrameLevels = {
    ["Interface\\CHARACTERFRAME\\UI-Party-Border"] = 1,
    ["Interface\\Tooltips\\ChatBubble-Backdrop"] = 1,
}

function addon:SetLSMBorders(castbar, cast, db)
    -- Create new frame to contain our LSM backdrop
    if not castbar.BorderFrame then
        castbar.BorderFrame = CreateFrame("Frame", nil, castbar)
        castbar.BorderFrame:SetPoint("TOPLEFT", castbar, -2, 2)
        castbar.BorderFrame:SetPoint("BOTTOMRIGHT", castbar, 2, -2)
    end

    -- Apply backdrop if it isn't already active
    if castbar.BorderFrame.currentTexture ~= db.castBorder or castbar:GetHeight() ~= castbar.BorderFrame.currentHeight then
        castbar.BorderFrame:SetBackdrop({
            edgeFile = db.castBorder,
            tile = false, tileSize = 0,
            edgeSize = castbar:GetHeight(),
        })
        castbar.BorderFrame.currentTexture = db.castBorder
        castbar.BorderFrame.currentHeight = castbar:GetHeight()
    end

    castbar.Border:SetAlpha(0) -- hide default border
    castbar.BorderFrame:SetAlpha(1)
    castbar.BorderFrame:SetFrameLevel(textureFrameLevels[db.castBorder] or castbar:GetFrameLevel() + 1)
    castbar.BorderFrame:SetBackdropBorderColor(unpack(db.borderColor))
end

function addon:SetCastbarFonts(castbar, cast, db)
    local fontName, fontHeight = castbar.Text:GetFont()
    if fontName ~= db.castFont or db.castFontSize ~= fontHeight then
        castbar.Text:SetFont(db.castFont, db.castFontSize)
        castbar.Timer:SetFont(db.castFont, db.castFontSize)
    end

    local c = db.textColor
    castbar.Text:SetTextColor(c[1], c[2], c[3], c[4])
    castbar.Timer:SetTextColor(c[1], c[2], c[3], c[4])
    castbar.Text:SetPoint("LEFT", db.textPositionX, db.textPositionY)
end

local function GetStatusBarBackgroundTexture(statusbar)
    if statusbar.Background then return statusbar.Background end

    for _, v in pairs({ statusbar:GetRegions() }) do
        if v.GetTexture and v:GetTexture() and strfind(v:GetTexture(), "Color-") then
            return v
        end
    end
end

function addon:DisplayCastbar(castbar, unitID)
    local parentFrame = AnchorManager:GetAnchor(unitID)
    if not parentFrame then return end

    local db = self.db[self:GetUnitType(unitID)]

    if not castbar.animationGroup then
        castbar.animationGroup = castbar:CreateAnimationGroup()
        castbar.animationGroup:SetToFinalAlpha(true)
        castbar.fade = castbar.animationGroup:CreateAnimation("Alpha")
        castbar.fade:SetOrder(1)
        castbar.fade:SetFromAlpha(1)
        castbar.fade:SetToAlpha(0)
        castbar.fade:SetSmoothing("OUT")
    end
    castbar.animationGroup:Stop()

    if not castbar.Background then
        castbar.Background = GetStatusBarBackgroundTexture(castbar)
    end
    castbar.Background:SetColorTexture(unpack(db.statusBackgroundColor))

    local cast = castbar._data
    if cast.isChanneled then
        castbar:SetStatusBarColor(unpack(db.statusColorChannel))
    else
        castbar:SetStatusBarColor(unpack(db.statusColor))
    end

    -- Note: since frames are recycled and we also allow having different styles
    -- between castbars for all the unitframes, we need to always update the style here
    -- incase it was modified to something else on last recycle
    self:SetCastbarStyle(castbar, cast, db)
    self:SetCastbarFonts(castbar, cast, db)
    self:SetCastbarIconAndText(castbar, cast, db)

    if unitID == "target" and self.db.target.autoPosition then
        self:SetTargetCastbarPosition(castbar, parentFrame)
    else
        castbar:SetPoint(db.position[1], parentFrame, db.position[2], db.position[3])
    end

    if not castbar.isTesting then
        castbar:SetMinMaxValues(0, cast.maxValue)
        castbar:SetValue(0)
        castbar.Spark:SetPoint("CENTER", castbar, "LEFT", 0, 0)
    end

    castbar.Flash:Hide()
    castbar:SetParent(parentFrame)
    castbar.Text:SetWidth(db.width - 10) -- ensures text gets truncated
    castbar:SetAlpha(1)
    castbar:Show()
end

function addon:HideCastbar(castbar, unitID, noFadeOut)
    if noFadeOut then
        castbar:SetAlpha(0)
        castbar:Hide()
        return
    end

    local cast = castbar._data
    if cast and (cast.isInterrupted or cast.isFailed) then
        castbar.Text:SetText(cast.isInterrupted and _G.INTERRUPTED or _G.FAILED)
        castbar:SetStatusBarColor(unpack(self.db[self:GetUnitType(unitID)].statusColorFailed))
        castbar:SetMinMaxValues(0, 1)
        castbar:SetValue(1)
        castbar.Spark:SetAlpha(0)
    end

    if cast and cast.isCastComplete then -- SPELL_CAST_SUCCESS
        if castbar.Border:GetAlpha() == 1 then -- not using LSM borders
            local tex = castbar.Border:GetTexture()
            if tex == "Interface\\CastingBar\\UI-CastingBar-Border" or tex == "Interface\\CastingBar\\UI-CastingBar-Border-Small" then
                if not cast.isChanneled then
                    castbar.Flash:SetVertexColor(1, 1, 1)
                else
                    castbar.Flash:SetVertexColor(0, 1, 0)
                end
                castbar.Flash:Show()
            end
        end

        castbar.Spark:SetAlpha(0)
        castbar:SetMinMaxValues(0, 1)
        if not cast.isChanneled then
            castbar:SetStatusBarColor(0, 1, 0)
            castbar:SetValue(1)
        else
            castbar:SetValue(0)
        end
    end

    if castbar:GetAlpha() > 0 and castbar.fade then
        castbar.fade:SetStartDelay(0) -- reset
        if cast then
            if cast.isInterrupted or cast.isFailed then
                castbar.fade:SetStartDelay(0.5)
            end
        end
        castbar.fade:SetDuration(cast and cast.isInterrupted and 1.2 or 0.3)
        castbar.animationGroup:Play()
    end
end

function addon:SkinPlayerCastbar()
    local db = self.db.player
    if not db.enabled then return end

    if not CastingBarFrame.Timer then
        CastingBarFrame.Timer = CastingBarFrame:CreateFontString(nil, "OVERLAY")
        CastingBarFrame.Timer:SetTextColor(1, 1, 1)
        CastingBarFrame.Timer:SetFontObject("SystemFont_Shadow_Small")
        CastingBarFrame:HookScript("OnUpdate", function(frame)
            if db.enabled and db.showTimer then
                local spellText = frame.Text and frame.Text:GetText()
                if spellText then
                    frame.Timer:SetPoint("RIGHT", CastingBarFrame, (spellText:len() >= 19) and 30 or -6, 0)
                end

                if frame.fadeOut or (not frame.casting and not frame.channeling) then
                    -- just show no text at zero, the numbers looks kinda weird when Flash animation is playing
                    return frame.Timer:SetText("")
                end

                if not frame.channeling then
                    frame.Timer:SetFormattedText("%.1f", frame.maxValue - frame.value)
                else
                    frame.Timer:SetFormattedText("%.1f", frame.value)
                end
            end
        end)
    end
    CastingBarFrame.Timer:SetShown(db.showTimer)

    if not CastingBarFrame.CC_isHooked then
        CastingBarFrame:HookScript("OnShow", function(frame)
            if frame.Icon:GetTexture() == 136235 then
                frame.Icon:SetTexture(136243)
            end
        end)

        hooksecurefunc("PlayerFrame_DetachCastBar", function()
            addon:SkinPlayerCastbar()
        end)

        hooksecurefunc("PlayerFrame_AttachCastBar", function()
            addon:SkinPlayerCastbar()
        end)
        CastingBarFrame.CC_isHooked = true
    end

    if db.castBorder == "Interface\\CastingBar\\UI-CastingBar-Border" or db.castBorder == "Interface\\CastingBar\\UI-CastingBar-Border-Small" then
        CastingBarFrame.Flash:SetTexture("Interface\\CastingBar\\UI-CastingBar-Flash")
        CastingBarFrame.Flash:SetSize(db.width + 61, db.height + 51)
        CastingBarFrame.Flash:SetPoint("TOP", 0, 26)
    else
        CastingBarFrame.Flash:SetTexture(nil) -- hide it by removing texture, SetAlpha() or Hide() wont work without messing with blizz code
    end

    CastingBarFrame_SetStartCastColor(CastingBarFrame, unpack(db.statusColor))
	CastingBarFrame_SetStartChannelColor(CastingBarFrame, unpack(db.statusColorChannel))
	--CastingBarFrame_SetFinishedCastColor(CastingBarFrame, unpack(db.statusColor))
	--CastingBarFrame_SetNonInterruptibleCastColor(CastingBarFrame, 0.7, 0.7, 0.7)
    CastingBarFrame_SetFailedCastColor(CastingBarFrame, unpack(db.statusColorFailed))
    if CastingBarFrame.isTesting then
        CastingBarFrame:SetStatusBarColor(CastingBarFrame.startCastColor:GetRGB())
    end

    CastingBarFrame.Text:ClearAllPoints()
    CastingBarFrame.Text:SetPoint("CENTER")
    CastingBarFrame.Icon:ClearAllPoints()
    CastingBarFrame.Icon:SetShown(db.showIcon)

    if not CastingBarFrame.Background then
        CastingBarFrame.Background = GetStatusBarBackgroundTexture(CastingBarFrame)
    end
    CastingBarFrame.Background:SetColorTexture(unpack(db.statusBackgroundColor))

    if not db.autoPosition then
        CastingBarFrame:ClearAllPoints()
        CastingBarFrame.ignoreFramePositionManager = true

        local pos = db.position
        CastingBarFrame:SetPoint(pos[1], UIParent, pos[2], pos[3])
    else
        if not _G.PLAYER_FRAME_CASTBARS_SHOWN then
            CastingBarFrame.ignoreFramePositionManager = false
            CastingBarFrame:ClearAllPoints()
            CastingBarFrame:SetPoint("BOTTOM", UIParent, 0, 150)
        end
    end

    self:SetCastbarStyle(CastingBarFrame, nil, db)
    self:SetCastbarFonts(CastingBarFrame, nil, db)
end

function addon:CreateOrUpdateSecureFocusButton(text)
    if not self.FocusButton then
        -- Create an invisible secure click trigger above the nonsecure castbar frame
        self.FocusButton = CreateFrame("Button", "FocusCastbar", UIParent, "SecureActionButtonTemplate")
        self.FocusButton:SetAttribute("type", "macro")
        --self.FocusButton:SetAllPoints(self.FocusFrame)
        --self.FocusButton:SetSize(ClassicCastbarsDB.focus.width + 5, ClassicCastbarsDB.focus.height + 35)
    end

    local db = ClassicCastbarsDB.focus
    self.FocusButton:SetPoint(db.position[1], UIParent, db.position[2], db.position[3] + 30)
    self.FocusButton:SetSize(db.width + 5, db.height + 35)

    self.FocusButton:SetAttribute("macrotext", "/targetexact " .. text)
    self.FocusFrame.Text:SetText(text)
end

local NewTimer = _G.C_Timer.NewTimer
local focusTargetTimer
local focusTargetResetTimer

function addon:SetFocusDisplay(text, unitID)
    if focusTargetTimer and not focusTargetTimer:IsCancelled() then
        focusTargetTimer:Cancel()
        focusTargetTimer = nil
    end
    if focusTargetResetTimer and not focusTargetResetTimer:IsCancelled() then
        focusTargetResetTimer:Cancel()
        focusTargetResetTimer = nil
    end

    if not text then -- clear focus
        if self.FocusFrame then
            self.FocusFrame.Text:SetText("")
        end

        if self.FocusButton then
            if not InCombatLockdown() then
                self.FocusButton:SetAttribute("macrotext", "")
            else
                -- If we're in combat try to check every 4s if we left combat and can update secure frame
                local function ClearFocusTarget()
                    if not InCombatLockdown() then
                        addon.FocusButton:SetAttribute("macrotext", "")
                    else
                        focusTargetResetTimer = NewTimer(4, ClearFocusTarget)
                    end
                end
                focusTargetResetTimer = NewTimer(4, ClearFocusTarget)
            end
        end

        return
    end

    if not self.FocusFrame then
        -- Create a new unsecure frame to display focus text. We dont reuse the castbar frame as we want to
        -- display this text even when the castbar is hidden
        self.FocusFrame = CreateFrame("Frame", nil, UIParent)
        self.FocusFrame:SetSize(ClassicCastbarsDB.focus.width + 5, ClassicCastbarsDB.focus.height + 35)
        self.FocusFrame.Text = self.FocusFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLargeOutline")
        self.FocusFrame.Text:SetPoint("CENTER", self.FocusFrame, 0, 20)
    end

    if UnitIsPlayer(unitID) then
        self.FocusFrame.Text:SetTextColor(RAID_CLASS_COLORS[select(2, UnitClass(unitID))]:GetRGBA())
    else
        self.FocusFrame.Text:SetTextColor(1, 0.819, 0, 1)
    end

    local isInCombat = InCombatLockdown()
    if not isInCombat then
        self:CreateOrUpdateSecureFocusButton(text)
    else
        -- If we're in combat try to check every 4s if we left combat and can update secure frame
        local function UpdateFocusTarget()
            if not InCombatLockdown() then
                addon:CreateOrUpdateSecureFocusButton(text)
            else
                focusTargetTimer = NewTimer(4, UpdateFocusTarget)
            end
        end

        focusTargetTimer = NewTimer(4, UpdateFocusTarget)
    end

    -- HACK: quickly create the focus castbar if it doesnt exist and hide it.
    -- This is just to make anchoring easier for self.FocusFrame on first usage
    if not activeFrames.focus then
        local pos = ClassicCastbarsDB.focus.position
        local castbar = self:GetCastbarFrame("focus")
        castbar:ClearAllPoints()
        castbar:SetParent(UIParent)
        castbar:SetPoint(pos[1], UIParent, pos[2], pos[3])
    end

    self.FocusFrame.Text:SetText(isInCombat and text .. " (|cffff0000P|r)" or text)
    self.FocusFrame:SetAllPoints(activeFrames.focus)
end