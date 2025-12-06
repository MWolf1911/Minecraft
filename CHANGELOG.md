# Wolf's Den 5 Server Changelog

All notable changes to this Minecraft server instance are documented here.
Modpack changelog: https://community.flatlineroleplay.com/wd5_changelog.txt

---

## [Unreleased]

### Added
- **RPG Series Class System:**
  - Wizards (RPG Series) - Arcane, Fire, and Frost magic
  - Paladins & Priests (RPG Series) - Holy combat and healing
  - Rogues & Warriors (RPG Series) - Stealth and melee combat
  - Archers (RPG Series) - Bow and crossbow combat skills
- **LNE (Loot & Explore) Add-ons:**
  - LNE Wizards - Additional wizard structures and special staves
  - LNE Paladins - Additional paladin structures and holy weapons
  - LNE Rogues - Additional rogue structures and specialized weapons
  - LNE Archers - Additional archer structures and specialized bows
- **RPG Series Supporting Mods:**
  - Spell Engine - Core spell system library
  - Spell Power Attributes - Magic attribute system
  - Skill Tree (RPG Series) - 100+ skill nodes for class progression
  - Pufferfish Skills - Skill tree framework
  - Ranged Weapon API - Enhanced ranged combat
  - Jewelry - Equipment system for accessories
  - Runes - Spell ammunition system
  - Relics - Powerful artifact items
  - Armory - Additional armor and weapons
  - Arsenal - Weapon expansion
  - Shield API - Enhanced shield mechanics
  - Bundle API - Inventory management
  - Structure Pool API - Structure generation
  - AzureLib Armor - Armor animation library
  - More Relics - Additional relic items
  - Archers Expansion - Extended archer content
  - More RPG Library - RPG framework extensions
- **Village Structures:**
  - Gazebo - Spell binding tables in villages
  - Village Taverns - New village structures

### Changed

### Fixed

### Removed
- Iron's Spells 'n Spellbooks (replaced by RPG Series class system)
- Iron's RPG Tweaks (companion mod for Iron's Spells)

---

## Modpack Version History

### 0.0.9 - 2025-12-06

**Server Changes:**
- Updated NeoForge from 21.1.193 to 21.1.209
- Updated 109 mods to latest versions

**Bug Fixes:**
- Fixed client crash caused by mods requiring NeoForge 21.1.200+
- Fixed Horseman mod connection issue (removed non-modpack mod)

**Technical Notes:**
- Both server and client now require NeoForge 21.1.209 minimum
- Mods requiring newer NeoForge: Create, Moonlight, Copycats, Numismatics, BCC, and others

### 0.0.8
**Added:**
- No Hostiles Around Campfire
- Damage Numbers
- Iron's Spells 'n Spellbooks
- Iron's RPG Tweaks
- Sound Physics Remastered
- Sounds
- Client Sort

### 0.0.7
**Added:**
- Journeymap
- Journeymap Webmap
- Open Parties and Claims
- JourneyPAC

**Removed:**
- Bluemap (Large filesizes)

### 0.0.6
**Added:**
- CraftTweaker
- Recipe Generator

### 0.0.5
**Added:**
- William Wyther's Overhauled Overworld

**Changed:**
- Updated Create: The Factory Must Grow
- Updated JEI
- Updated Accessories
- Updated Smarter Farmers
- Updated Sophisticated Core
- Updated Sophisticated Backpacks
- Updated Sophisticated Storage
- Updated Moonlight Lib

**Removed:**
- Skyblock Builder
- SkyGUIs
- Still Life

### 0.0.4
**Added:**
- Sparse Structures
- April Fools

### 0.0.3
**Added:**
- Bluemap

**Removed:**
- Journeymap

### 0.0.2
**Added:**
- Create: The Factory Must Grow
- Clay Soldiers Remake
- Ender Dragon Fight Remastered
- Better Climbing
- Better Clouds
- Better Days

### 0.0.1
**Initial Release**

---

## Server Configuration Changes

*This section tracks server-specific config edits, mod disables, and operational changes not reflected in the modpack versions above.*

### 2025-12-06
**Fixed:**
- Disabled Horseman mod (`horseman-neoforge-1.21.1-1.5.2.1.jar.disabled`) on client
  - Mod not included in Wolf's Den 4 modpack, causing connection error due to channel mismatch
  - Horseman is client-side QOL mod (improves horse riding mechanics) - server doesn't require it

### Format Guide
Each entry should include:
- **Date** - When the change was made
- **Category** - Added/Changed/Fixed/Removed
- **Description** - Brief explanation of what changed
- **Impact** - How it affects gameplay/server (if significant)

Example:
```
### 2025-12-06
**Changed:**
- `config/nohostilesaroundcampfire.json5`: Increased `preventHostilesRadius` from 48 to 64 blocks
  - Impact: Campfires now protect a larger area from hostile mob spawns

**Fixed:**
- Disabled `flowing_fluids` mod due to compatibility issues with Create mod
  - Renamed to `flowing_fluids_neoforge_1.21.1-0.6.1.jar.disabled`
```
