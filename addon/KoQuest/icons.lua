-- Custom Icons for Specific Nodes
--
-- This file contains custom icon definitions for specific nodes in the game.
-- Each node has a unique identifier that is used to determine its localized name.
-- Negative values are used to assign icons to game objects. Positive values are
-- used to assign icons to units. To avoid duplicates, it's essential to use only
-- one id per object or unit name.

do -- /kodb track mines
  KoDatabase:AddCustomIcon(-1731, "img\\tracking\\mines\\Copper") -- Copper Vein
  KoDatabase:AddCustomIcon(-1732, "img\\tracking\\mines\\Tin") -- Tin Vein
  KoDatabase:AddCustomIcon(-1733, "img\\tracking\\mines\\Silver") -- Silver Vein
  KoDatabase:AddCustomIcon(-73940, "img\\tracking\\mines\\Silver") -- Ooze Covered Silver Vein
  KoDatabase:AddCustomIcon(-1735, "img\\tracking\\mines\\Iron") -- Iron Deposit
  KoDatabase:AddCustomIcon(-1734, "img\\tracking\\mines\\Gold") -- Gold Vein
  KoDatabase:AddCustomIcon(-73941, "img\\tracking\\mines\\Gold") -- Ooze Covered Gold Vein
  KoDatabase:AddCustomIcon(-2040, "img\\tracking\\mines\\Mithril") -- Mithril Deposit
  KoDatabase:AddCustomIcon(-123310,"img\\tracking\\mines\\Mithril") -- Ooze Covered Mithril Deposit
  KoDatabase:AddCustomIcon(-2047, "img\\tracking\\mines\\TrueSilver") -- Truesilver Deposit
  KoDatabase:AddCustomIcon(-123309,"img\\tracking\\mines\\TrueSilver") -- Ooze Covered Truesilver Deposit
  KoDatabase:AddCustomIcon(-324, "img\\tracking\\mines\\Thorium") -- Small Thorium Vein
  KoDatabase:AddCustomIcon(-123848, "img\\tracking\\mines\\Thorium") -- Ooze Covered Thorium Vein
  KoDatabase:AddCustomIcon(-180215, "img\\tracking\\mines\\Thorium") -- Hakkari Thorium Vein
  KoDatabase:AddCustomIcon(-175404, "img\\tracking\\mines\\RichThorium") -- Rich Thorium Vein
  KoDatabase:AddCustomIcon(-177388, "img\\tracking\\mines\\RichThorium") -- Ooze Covered Rich Thorium Vein
  KoDatabase:AddCustomIcon(-165658, "img\\tracking\\mines\\DarkIron") -- Dark Iron Deposit
  KoDatabase:AddCustomIcon(-2653, "img\\tracking\\mines\\LesserBloodstone") -- Lesser Bloodstone Deposit
  KoDatabase:AddCustomIcon(-181555, "img\\tracking\\mines\\FelIron") -- Fel Iron Deposit
  KoDatabase:AddCustomIcon(-181556, "img\\tracking\\mines\\Adamantite") -- Adamantite Deposit
  KoDatabase:AddCustomIcon(-181569, "img\\tracking\\mines\\Adamantite") -- Rich Adamantite Deposit
  KoDatabase:AddCustomIcon(-181557, "img\\tracking\\mines\\Khorium") -- Khorium Vein
  KoDatabase:AddCustomIcon(-185877, "img\\tracking\\mines\\Nethercite") -- Nethercite Deposit
end

do -- /kodb track herbs
  KoDatabase:AddCustomIcon(-142141, "img\\tracking\\herbs\\ArthasTears") -- Arthas' Tears
  KoDatabase:AddCustomIcon(-176589, "img\\tracking\\herbs\\BlackLotus") -- Black Lotus
  KoDatabase:AddCustomIcon(-142143, "img\\tracking\\herbs\\Blindweed") -- Blindweed
  KoDatabase:AddCustomIcon(-1621, "img\\tracking\\herbs\\Briarthorn") -- Briarthorn
  KoDatabase:AddCustomIcon(-1622, "img\\tracking\\herbs\\Bruiseweed") -- Bruiseweed
  KoDatabase:AddCustomIcon(-176584, "img\\tracking\\herbs\\Dreamfoil") -- Dreamfoil
  KoDatabase:AddCustomIcon(-1619, "img\\tracking\\herbs\\Earthroot") -- Earthroot
  KoDatabase:AddCustomIcon(-2042, "img\\tracking\\herbs\\Fadeleaf") -- Fadeleaf
  KoDatabase:AddCustomIcon(-2866, "img\\tracking\\herbs\\Firebloom") -- Firebloom
  KoDatabase:AddCustomIcon(-142144, "img\\tracking\\herbs\\GhostMushroom") -- Ghost Mushroom
  KoDatabase:AddCustomIcon(-176583, "img\\tracking\\herbs\\GoldenSansam") -- Golden Sansam
  KoDatabase:AddCustomIcon(-2046, "img\\tracking\\herbs\\Goldthorn") -- Goldthorn
  KoDatabase:AddCustomIcon(-1628, "img\\tracking\\herbs\\GraveMoss") -- Grave Moss
  KoDatabase:AddCustomIcon(-142145, "img\\tracking\\herbs\\Gromsblood") -- Gromsblood
  KoDatabase:AddCustomIcon(-176588, "img\\tracking\\herbs\\Icecap") -- Icecap
  KoDatabase:AddCustomIcon(-2043, "img\\tracking\\herbs\\KhadgarsWhisker") -- Khadgar's Whisker
  KoDatabase:AddCustomIcon(-1624, "img\\tracking\\herbs\\Kingsblood") -- Kingsblood
  KoDatabase:AddCustomIcon(-2041, "img\\tracking\\herbs\\Liferoot") -- Liferoot
  KoDatabase:AddCustomIcon(-1620, "img\\tracking\\herbs\\Mageroyal") -- Mageroyal
  KoDatabase:AddCustomIcon(-176586, "img\\tracking\\herbs\\MountainSilversage") -- Mountain Silversage
  KoDatabase:AddCustomIcon(-1618, "img\\tracking\\herbs\\Peacebloom") -- Peacebloom
  KoDatabase:AddCustomIcon(-176587, "img\\tracking\\herbs\\Plaguebloom") -- Plaguebloom
  KoDatabase:AddCustomIcon(-142140, "img\\tracking\\herbs\\PurpleLotus") -- Purple Lotus
  KoDatabase:AddCustomIcon(-1617, "img\\tracking\\herbs\\Silverleaf") -- Silverleaf
  KoDatabase:AddCustomIcon(-2045, "img\\tracking\\herbs\\Stranglekelp") -- Stranglekelp
  KoDatabase:AddCustomIcon(-142142, "img\\tracking\\herbs\\Sungrass") -- Sungrass
  KoDatabase:AddCustomIcon(-1623, "img\\tracking\\herbs\\WildSteelbloom") -- Wild Steelbloom
  KoDatabase:AddCustomIcon(-2044, "img\\tracking\\herbs\\Wintersbite") -- Wintersbite
  KoDatabase:AddCustomIcon(-181270, "img\\tracking\\herbs\\Felweed") -- Felweed
  KoDatabase:AddCustomIcon(-181271, "img\\tracking\\herbs\\DreamingGlory") -- Dreaming Glory
  KoDatabase:AddCustomIcon(-181166, "img\\tracking\\herbs\\Stranglekelp") -- Bloodthistle
  KoDatabase:AddCustomIcon(-181275, "img\\tracking\\herbs\\Ragveil") -- Ragveil
  KoDatabase:AddCustomIcon(-181276, "img\\tracking\\herbs\\FlameCap") -- Flame Cap
  KoDatabase:AddCustomIcon(-181277, "img\\tracking\\herbs\\Terocone") -- Terocone
  KoDatabase:AddCustomIcon(-181278, "img\\tracking\\herbs\\AncientLichen") -- Ancient Lichen
  KoDatabase:AddCustomIcon(-181279, "img\\tracking\\herbs\\Netherbloom") -- Netherbloom
  KoDatabase:AddCustomIcon(-181280, "img\\tracking\\herbs\\NightmareVine") -- Nightmare Vine
  KoDatabase:AddCustomIcon(-181281, "img\\tracking\\herbs\\ManaThistle") -- Mana Thistle
  KoDatabase:AddCustomIcon(-185881, "img\\tracking\\herbs\\Netherdust") -- Netherdust Bush
  KoDatabase:AddCustomIcon(-157936, "img\\tracking\\herbs\\GraveMoss") -- Un'Goro Dirt Pile
end

do -- /kodb track chests
  KoDatabase:AddCustomIcon(-2039, "img\\tracking\\chests\\Chest") -- Hidden Strongbox
  KoDatabase:AddCustomIcon(-2744, "img\\tracking\\chests\\Clam") -- Giant Clam
  KoDatabase:AddCustomIcon(-2843, "img\\tracking\\chests\\Chest") -- Battered Chest
  KoDatabase:AddCustomIcon(-2844, "img\\tracking\\chests\\Chest") -- Tattered Chest
  KoDatabase:AddCustomIcon(-2850, "img\\tracking\\chests\\Chest") -- Solid Chest
  KoDatabase:AddCustomIcon(-3658, "img\\tracking\\chests\\Barrel") -- Water Barrel
  KoDatabase:AddCustomIcon(-3659, "img\\tracking\\chests\\Barrel") -- Barrel of Melon Juice
  KoDatabase:AddCustomIcon(-3660, "img\\tracking\\chests\\Crate") -- Armor Crate
  KoDatabase:AddCustomIcon(-3661, "img\\tracking\\chests\\Crate") -- Weapon Crate
  KoDatabase:AddCustomIcon(-3662, "img\\tracking\\chests\\Crate") -- Food Crate
  KoDatabase:AddCustomIcon(-3705, "img\\tracking\\chests\\Barrel") -- Barrel of Milk
  KoDatabase:AddCustomIcon(-3706, "img\\tracking\\chests\\Barrel") -- Barrel of Sweet Nectar
  KoDatabase:AddCustomIcon(-3714, "img\\tracking\\chests\\Chest") -- Alliance Strongbox
  KoDatabase:AddCustomIcon(-19019, "img\\tracking\\chests\\Crate") -- Box of Assorted Parts
  KoDatabase:AddCustomIcon(-142191, "img\\tracking\\chests\\Crate") -- Horde Supply Crate
  KoDatabase:AddCustomIcon(-176582, "img\\tracking\\chests\\ShellfishTrap") -- Shellfish Trap
  KoDatabase:AddCustomIcon(-178244, "img\\tracking\\chests\\Footlocker") -- Practice Lockbox
  KoDatabase:AddCustomIcon(-179486, "img\\tracking\\chests\\Footlocker") -- Battered Footlocker
  KoDatabase:AddCustomIcon(-179487, "img\\tracking\\chests\\Footlocker") -- Waterlogged Footlocker
  KoDatabase:AddCustomIcon(-179492, "img\\tracking\\chests\\Footlocker") -- Dented Footlocker
  KoDatabase:AddCustomIcon(-179493, "img\\tracking\\chests\\Footlocker") -- Mossy Footlocker
  KoDatabase:AddCustomIcon(-179498, "img\\tracking\\chests\\Footlocker") -- Scarlet Footlocker
  KoDatabase:AddCustomIcon(-176213, "img\\tracking\\chests\\BloodHero") -- Blood of Heroes
  KoDatabase:AddCustomIcon(-164881, "img\\tracking\\chests\\NightDragon") -- Cleansed Night Dragon
  KoDatabase:AddCustomIcon(-164882, "img\\tracking\\chests\\Songflower") -- Cleansed Songflower
  KoDatabase:AddCustomIcon(-164883, "img\\tracking\\chests\\WhipperRoot") -- Cleansed Whipper Root
  KoDatabase:AddCustomIcon(-164884, "img\\tracking\\chests\\WindBlossom") -- Cleansed Windblossom
  KoDatabase:AddCustomIcon(-182053, "img\\tracking\\chests\\Glowcap") -- Glowcap
  KoDatabase:AddCustomIcon(-74447, "img\\tracking\\chests\\Chest") -- Large Iron Bound Chest
  KoDatabase:AddCustomIcon(-74448, "img\\tracking\\chests\\Chest") -- Large Solid Chest
  KoDatabase:AddCustomIcon(-75293, "img\\tracking\\chests\\Chest") -- Large Battered Chest
  KoDatabase:AddCustomIcon(-131978, "img\\tracking\\chests\\Chest") -- Large Mithril Bound Chest
  KoDatabase:AddCustomIcon(-131979, "img\\tracking\\chests\\Chest") -- Large Darkwood Chest
  KoDatabase:AddCustomIcon(-184930, "img\\tracking\\chests\\Chest") -- Solid Fel Iron Chest
  KoDatabase:AddCustomIcon(-184931, "img\\tracking\\chests\\Chest") -- Bound Fel Iron Chest
  KoDatabase:AddCustomIcon(-184936, "img\\tracking\\chests\\Chest") -- Bound Adamantite Chest
  KoDatabase:AddCustomIcon(-184939, "img\\tracking\\chests\\Chest") -- Solid Adamantite Chest
  KoDatabase:AddCustomIcon(-28604, "img\\tracking\\chests\\Crate") -- Scattered Crate
  KoDatabase:AddCustomIcon(-185915, "img\\tracking\\chests\\Egg") -- Netherwing Egg
  KoDatabase:AddCustomIcon(-123330, "img\\tracking\\chests\\Footlocker") -- Buccaneer's Strongbox
  KoDatabase:AddCustomIcon(-181665, "img\\tracking\\chests\\Footlocker") -- Burial Chest
  KoDatabase:AddCustomIcon(-184793, "img\\tracking\\chests\\Footlocker") -- Primitive Chest
  KoDatabase:AddCustomIcon(-184740, "img\\tracking\\chests\\Footlocker") -- Wicker Chest
  KoDatabase:AddCustomIcon(-181798, "img\\tracking\\chests\\Chest") -- Fel Iron Chest
  KoDatabase:AddCustomIcon(-181800, "img\\tracking\\chests\\Chest") -- Heavy Fel Iron Chest
  KoDatabase:AddCustomIcon(-181802, "img\\tracking\\chests\\Chest") -- Adamantite Bound Chest
  KoDatabase:AddCustomIcon(-181804, "img\\tracking\\chests\\Chest") -- Felsteel Chest
end