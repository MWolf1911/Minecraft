## Quick orientation

This is a **live NeoForge 1.21.1 modded Minecraft server** (not a Java dev project). AI agents help with config tuning, crash triage, automation scripts, and mod management—not compiling mods.

**Key paths:**
- `run.bat` / `run.sh` → Launch server (calls `java @user_jvm_args.txt @libraries/net/neoforged/neoforge/21.1.193/win_args.txt`)
- `user_jvm_args.txt` → Customize JVM memory (e.g., uncomment `-Xmx4G`)
- `mods/` → 178 server mods (see `scripts/server-mods.txt` for whitelist). Disabled mods have `.disabled` suffix
- `config/` → TOML/JSON5 files control mod behavior. Search by mod name to find settings
- `scripts/Sync-Mods-Modrinth.ps1` → Auto-syncs mods from [wolfs-den-4](https://modrinth.com/modpack/wolfs-den-4) every 5 min via Task Scheduler
- `logs/latest.log`, `crash-reports/`, `debug/` → Runtime diagnostics

**Critical constraints:**
- **Remote server on CubeCoders AMP** — AI cannot execute commands/run server. Provide file edits only.
- Daily restart at 00:00 (midnight). Mod updates apply after restart.
- `server.properties` uses `online-mode=false` (LAN setup). Don't change network settings without approval.

**Local client instance:**
- `c:\Users\Matt\AppData\Roaming\ModrinthApp\profiles\Wolf_s Den 5\` → Local Minecraft client for testing/development
- Client has full modpack (client+server mods), server has only server-side subset
- Use client `config/` for testing client-side settings, `mods/` for verifying mod versions
- Client configs may differ from server (e.g., graphics, UI mods) — sync only shared configs

## Architecture

**Runtime flow:**  
`run.bat` → NeoForge loader (`neoforge-21.1.193-server.jar`) → Loads ~178 mods from `mods/` → Reads config from `config/` → Server starts with world state in `world/`

**Mod ecosystem:**
- Core libs: `cloth-config`, `geckolib`, `architectury`, `balm`, `puzzleslib` (version-locked to NeoForge)
- Content mods: Create, Farmer's Delight, YUNG's structures, etc.
- Some mods depend on companion libs (e.g., `create-central-kitchen` needs `create`)

**Automated mod sync:**
`Sync-Mods-Modrinth.ps1` (runs every 5 min) → Checks Modrinth API for pack updates → Downloads new `.mrpack` → Extracts only mods in `server-mods.txt` (179 project IDs) → Backs up old versions to `mods/backups/` (keeps last 10) → Logs to `logs/mod-sync/`

## Developer workflows

### Config changes
1. Find mod config: `grep -r "modname" config/` or check `config/<modname>*.{toml,json5}`
2. Edit values (e.g., `config/nohostilesaroundcampfire.json5` sets `preventHostilesRadius`)
3. Operator restarts server (changes apply on next boot)

### Crash triage
1. Read `logs/latest.log` (tail) or `crash-reports/*.txt`
2. Identify problematic mod via stack trace (e.g., `at net.ironsspellbooks...`)
3. Check `mods/` for jar version and `config/` for misconfigurations
4. Use `CrashAssistant` output for hints

### Memory tuning
Edit `user_jvm_args.txt`: uncomment and set `-Xmx4G` (or higher). Operator must restart server via `run.bat`.

### Disable a mod
Rename `mods/<modname>.jar` → `mods/<modname>.jar.disabled` (preserve for easy re-enable). Never delete.

### Add/remove server mods
Edit `scripts/server-mods.txt`: use project IDs (format: `projectID  # mod-name`). Example:
```
EsAfCjCV  # appleskin-neoforge-mc1.21
```
Sync happens automatically within 5 min. Check `logs/mod-sync/` for status.

### Test config changes locally
1. Edit config in client instance: `c:\Users\Matt\AppData\Roaming\ModrinthApp\profiles\Wolf_s Den 5\config\`
2. Launch client, join server, verify behavior
3. If server-side config, copy to server `config/` and restart server

### Manual sync testing
```powershell
# Check for updates (no download)
powershell -NoProfile -ExecutionPolicy Bypass -Command "& 'Z:\Instances\WolfsDen401\Minecraft\scripts\Sync-Mods-Modrinth.ps1' -CheckOnly"

# Force sync now
powershell -NoProfile -ExecutionPolicy Bypass -Command "& 'Z:\Instances\WolfsDen401\Minecraft\scripts\Sync-Mods-Modrinth.ps1' -ForceUpdate"
```

## Project conventions

**Config files:** Use TOML/JSON5 for mod settings. Many mods use `common`/`server` split (e.g., `balm-common.toml`, `create-server.toml`).

**Mod ID format:** `scripts/server-mods.txt` uses Modrinth project IDs (e.g., `lhGA9TYQ` → `architectury`), not filenames. This survives version updates.

**Backup strategy:**
- Mod sync auto-backups to `mods/backups/` (10 versions per mod)
- `SimpleBackups` mod handles world snapshots
- Before major config edits, manually copy `config/` directory

**Disabled mod pattern:** Suffix `.disabled` to jar name to skip loading (e.g., `immersive_portals-6.0.7-all.jar.disabled`). Do NOT delete mods—disabling preserves rollback option.

**No plugin folder:** This is NeoForge (mods), not Bukkit/Spigot (plugins). `plugins/` directory is unused.

## Integration points

**NeoForge runtime:** `libraries/net/neoforged/neoforge/21.1.193/` contains `win_args.txt`/`unix_args.txt` (startup params). Only edit if upgrading NeoForge version.

**Modrinth API:** Sync script queries `https://api.modrinth.com/v2/project/wolfs-den-4` for updates. Cache in `scripts/.modrinth-cache/`.

**Changelog:** Modpack changelog hosted at `https://community.flatlineroleplay.com/wd5_changelog.txt` (displayed in main menu).

**Server properties:** `server.properties` uses `online-mode=false` (LAN), `max-players=20`, `level-seed=3741407479215385235`. Changing network settings affects connectivity.

## Examples

**Change campfire protection radius:**
Edit `config/nohostilesaroundcampfire.json5`:
```json5
"preventHostilesRadius": 48,  // change to 64
```

**Disable Create's steel production:**
Edit `config/create-server.toml`:
```toml
[recipes]
  allowIronInBlastFurnace = false  // example pattern
```

**Find which mod adds a feature:**
Search configs: `grep -ri "feature_keyword" config/`  
Search mods: `ls mods/ | grep -i keyword`

**Diagnose "mod conflict" crash:**
1. Read `crash-reports/crash-*.txt`
2. Look for mixin conflicts (e.g., `Mixin apply failed`)
3. Check `mods/` for recently updated jars
4. Try disabling suspect mod (add `.disabled`)

## Safety rules

- **Never delete mods**—disable with `.disabled` suffix
- **Don't edit `world/` or `server.properties` networking** without explicit approval
- **Coordinate bulk config changes**—test on staging if available
- **Verify NeoForge compatibility** before suggesting mod upgrades
- **Always update `CHANGELOG.md`** when making config/mod changes

## Context sources

**For runtime issues:** `logs/latest.log`, `crash-reports/`, `debug.log`  
**For mod behavior:** `config/` (search by mod name)  
**For sync status:** `logs/mod-sync/sync-*.log`  
**For installed mods:** `mods/` (filenames), `scripts/server-mods.txt` (project IDs)  
**For client testing:** `c:\Users\Matt\AppData\Roaming\ModrinthApp\profiles\Wolf_s Den 5\` (local client configs, logs, mods)  
**For change history:** `CHANGELOG.md` (maintained by AI for all config/mod changes)
