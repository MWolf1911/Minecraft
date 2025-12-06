#Requires -Version 5.0
<#
.SYNOPSIS
    Auto-sync server mods from Modrinth modpack
    
.DESCRIPTION
    Periodically checks Modrinth for modpack updates, downloads latest version,
    and syncs only verified server mods. Designed to run on schedule.
    
.PARAMETER CheckOnly
    Only check for updates, don't sync
    
.PARAMETER ForceUpdate
    Force sync even if no update detected
    
.EXAMPLE
    .\Sync-Mods-Modrinth.ps1
    .\Sync-Mods-Modrinth.ps1 -CheckOnly
    .\Sync-Mods-Modrinth.ps1 -ForceUpdate
#>

param(
    [switch]$CheckOnly = $false,
    [switch]$ForceUpdate = $false
)

# ============ CONFIGURATION ============
$ModrinthPackSlug = "wolfs-den-4"
$ServerModsListPath = "Z:\Instances\WolfsDen401\Minecraft\scripts\server-mods.txt"
$RemoteModsPath = "Z:\Instances\WolfsDen401\Minecraft\mods"
$BackupPath = "$RemoteModsPath\backups"
$LogPath = "Z:\Instances\WolfsDen401\Minecraft\logs\mod-sync"
$TempExtractPath = "$env:TEMP\mrpack_sync_temp"
$CachePath = "Z:\Instances\WolfsDen401\Minecraft\scripts\.modrinth-cache"
$MaxBackupsPerMod = 10
$ModrinthApiBase = "https://api.modrinth.com/v2"

# Git Integration Settings
$GitEnabled = $false
$GitRepoPath = "Z:\Instances\WolfsDen401\Minecraft"
$GitRemoteName = "origin"
$GitBranch = "main"
$ChangelogPath = "Z:\Instances\WolfsDen401\Minecraft\CHANGELOG.md"
$GitAutoCommit = $false
$GitAutoPush = $false
# ======================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    if ($script:LogFile) {
        Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
}

function Initialize {
    foreach ($path in @($LogPath, $BackupPath, $CachePath)) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
    
    # Archive old log files
    Compress-OldLogs
    
    $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
    $script:LogFile = Join-Path $LogPath "sync-$timestamp.log"
    
    Write-Log "========== MOD SYNC - MODRINTH (AUTO) =========="
    Write-Log "Pack: $ModrinthPackSlug"
    Write-Log "CheckOnly: $CheckOnly | ForceUpdate: $ForceUpdate"
}

function Compress-OldLogs {
    Write-Host "Checking for old log files to archive..."
    
    $currentTime = Get-Date
    $oneHourAgo = $currentTime.AddHours(-1)
    
    # Get all log files older than 1 hour
    $oldLogs = Get-ChildItem -Path $LogPath -Filter "sync-*.log" -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.LastWriteTime -lt $oneHourAgo }
    
    if ($oldLogs.Count -eq 0) {
        Write-Host "No old log files to archive."
        return
    }
    
    # Group logs by their month (from LastWriteTime)
    $logsByMonth = $oldLogs | Group-Object { $_.LastWriteTime.ToString("yyyy-MM") }
    
    Write-Host "Archiving $($oldLogs.Count) old log file(s) across $($logsByMonth.Count) month(s)"
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        foreach ($monthGroup in $logsByMonth) {
            $archiveDate = $monthGroup.Name
            $archivePath = Join-Path $LogPath "archive-$archiveDate.zip"
            $monthLogs = $monthGroup.Group
            
            Write-Host "Processing archive: $archivePath ($($monthLogs.Count) logs)"
            
            # Create or update the archive for this month
            if (Test-Path $archivePath) {
                # Archive exists, append to it
                $archive = [System.IO.Compression.ZipFile]::Open($archivePath, 'Update')
            } else {
                # Create new archive
                $archive = [System.IO.Compression.ZipFile]::Open($archivePath, 'Create')
            }
            
            # Group logs by day within this month for folder organization
            $logsByDay = $monthLogs | Group-Object { $_.LastWriteTime.ToString("yyyy-MM-dd") }
            
            foreach ($dayGroup in $logsByDay) {
                $dayFolder = $dayGroup.Name
                
                foreach ($log in $dayGroup.Group) {
                    # Create entry path with day folder: yyyy-MM-dd/filename.log
                    $entryName = "$dayFolder/$($log.Name)"
                    $existingEntry = $archive.Entries | Where-Object { $_.FullName -eq $entryName }
                    
                    if (-not $existingEntry) {
                        $entry = $archive.CreateEntry($entryName)
                        $entryStream = $entry.Open()
                        $fileStream = [System.IO.File]::OpenRead($log.FullName)
                        $fileStream.CopyTo($entryStream)
                        $fileStream.Close()
                        $entryStream.Close()
                        Write-Host "  Added: $entryName"
                    } else {
                        Write-Host "  Skipped (already archived): $entryName"
                    }
                }
            }
            
            $archive.Dispose()
            
            # Delete archived log files for this month
            foreach ($log in $monthLogs) {
                Remove-Item $log.FullName -Force -ErrorAction SilentlyContinue
            }
            
            Write-Host "Archive complete for $archiveDate"
        }
        
        Write-Host "All archives complete. Old logs removed."
        
    } catch {
        Write-Host "Warning: Failed to archive logs: $_"
        # Don't fail the entire script if archiving fails
    }
}

function Get-ModrinthPackInfo {
    Write-Log "Querying Modrinth for pack info..."
    
    try {
        $url = "$ModrinthApiBase/project/$ModrinthPackSlug"
        $response = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        Write-Log "Retrieved pack info from Modrinth"
        return $response
    } catch {
        Write-Log "ERROR: Failed to query Modrinth API: $_" "ERROR"
        exit 1
    }
}

function Get-LatestPackVersion {
    param([object]$PackInfo)
    
    Write-Log "Fetching latest version..."
    
    try {
        $url = "$ModrinthApiBase/project/$($PackInfo.id)/version"
        $versions = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop
        
        if ($versions.Count -gt 0) {
            $latest = $versions[0]
            Write-Log "Latest version: $($latest.version_number)"
            Write-Log "  Released: $($latest.date_published)"
            return $latest
        } else {
            Write-Log "ERROR: No versions found" "ERROR"
            exit 1
        }
    } catch {
        Write-Log "ERROR: Failed to fetch versions: $_" "ERROR"
        exit 1
    }
}

function Test-UpdateNeeded {
    param([object]$LatestVersion)
    
    $cacheFile = Join-Path $CachePath "latest-version.txt"
    
    if (Test-Path $cacheFile) {
        $lastVersion = (Get-Content $cacheFile -Raw -ErrorAction SilentlyContinue).Trim()
        
        if ($lastVersion -eq $LatestVersion.id) {
            Write-Log "Already running latest version ($($LatestVersion.version_number))"
            return $false
        }
    }
    
    Write-Log "Update available: $($LatestVersion.version_number)"
    return $true
}

function Save-VersionCache {
    param([object]$LatestVersion)
    
    $cacheFile = Join-Path $CachePath "latest-version.txt"
    Set-Content -Path $cacheFile -Value $LatestVersion.id -Force
}

function Download-Mrpack {
    param([object]$Version)
    
    Write-Log "Downloading modpack version $($Version.version_number)..."
    
    $mrpackFile = $Version.files | Where-Object { $_.filename -like "*.mrpack" } | Select-Object -First 1
    
    if (-not $mrpackFile) {
        Write-Log "ERROR: No .mrpack file found in version" "ERROR"
        exit 1
    }
    
    $downloadUrl = $mrpackFile.url
    $tempMrpack = Join-Path $env:TEMP "temp_download.mrpack"
    
    try {
        Write-Log "Downloading from: $downloadUrl"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempMrpack -UseBasicParsing -ErrorAction Stop
        Write-Log "Downloaded: $(Split-Path $mrpackFile.filename -Leaf)"
        return $tempMrpack
    } catch {
        Write-Log "ERROR: Failed to download: $_" "ERROR"
        exit 1
    }
}

function Extract-Manifest {
    param([string]$MrpackFile)
    
    Write-Log "Extracting manifest..."
    
    if (Test-Path $TempExtractPath) {
        Remove-Item $TempExtractPath -Recurse -Force
    }
    New-Item -ItemType Directory $TempExtractPath | Out-Null
    
    $tempZip = Join-Path $TempExtractPath "temp.zip"
    Copy-Item $MrpackFile $tempZip
    
    try {
        Expand-Archive -Path $tempZip -DestinationPath $TempExtractPath -Force
    } catch {
        Write-Log "ERROR: Failed to extract: $_" "ERROR"
        exit 1
    }
    
    $manifestPath = Join-Path $TempExtractPath "modrinth.index.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Log "ERROR: modrinth.index.json not found" "ERROR"
        exit 1
    }
    
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    Write-Log "Manifest loaded ($($manifest.files.Count) mods total)"
    
    return $manifest
}

function Get-ServerModsWhitelist {
    Write-Log "Loading server mods whitelist..."
    
    if (-not (Test-Path $ServerModsListPath)) {
        Write-Log "ERROR: Server mods list not found: $ServerModsListPath" "ERROR"
        exit 1
    }
    
    $whitelist = @{}
    Get-Content $ServerModsListPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#")) {
            # Support both formats: project ID only, or "project-id  # comment"
            $projectId = ($line -split '#')[0].Trim()
            if ($projectId) {
                $whitelist[$projectId] = $true
            }
        }
    }
    
    Write-Log "Whitelist loaded ($($whitelist.Count) project IDs)"
    return $whitelist
}

function Get-MatchingMods {
    param(
        [object]$Manifest,
        [hashtable]$Whitelist
    )
    
    Write-Log "Matching mods to whitelist by project ID..."
    
    $matchedMods = @()
    $Manifest.files | ForEach-Object {
        $url = $_.downloads[0]
        # Extract project ID from URL: https://cdn.modrinth.com/data/PROJECT_ID/versions/...
        if ($url -match '/data/([^/]+)/') {
            $projectId = $matches[1]
            if ($Whitelist.ContainsKey($projectId)) {
                $matchedMods += $_
            }
        }
    }
    
    Write-Log "Matched $($matchedMods.Count) mods by project ID"
    return $matchedMods
}

function Backup-Mod {
    param([string]$ModPath)
    
    $modName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $ModPath -Leaf))
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $backupName = "$modName-$timestamp.jar"
    $backupPath = Join-Path $BackupPath $backupName
    
    Copy-Item -Path $ModPath -Destination $backupPath -Force
    Write-Log "  Backed up: $backupName"
    
    $oldBackups = @(Get-ChildItem $BackupPath -Filter "$modName-*.jar" -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending | Select-Object -Skip $MaxBackupsPerMod)
    if ($oldBackups.Count -gt 0) {
        $oldBackups | Remove-Item -Force
    }
}

function Sync-Mods {
    param([object[]]$MatchedMods)
    
    Write-Log "Syncing mods..."
    
    $added = 0
    $updated = 0
    $removed = 0
    $errors = 0
    $script:modChanges = @()
    
    $remoteMods = @{}
    Get-ChildItem $RemoteModsPath -Filter "*.jar" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $remoteMods[$_.Name] = $_
    }
    
    foreach ($mod in $MatchedMods) {
        $modName = Split-Path $mod.path -Leaf
        $modUrl = $mod.downloads[0]
        $remotePath = Join-Path $RemoteModsPath $modName
        
        if ($remoteMods.ContainsKey($modName)) {
            $remoteHash = (Get-FileHash -LiteralPath $remotePath -Algorithm SHA512).Hash
            
            if ($remoteHash -ne $mod.hashes.sha512) {
                Write-Log "UPDATE: $modName"
                Backup-Mod -ModPath $remotePath
                
                try {
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest -Uri $modUrl -OutFile $remotePath -UseBasicParsing -ErrorAction Stop
                    $updated++
                    $script:modChanges += @{ Action = "UPDATE"; FileName = $modName }
                } catch {
                    Write-Log "ERROR downloading $modName : $_" "ERROR"
                    $errors++
                }
            }
            $remoteMods.Remove($modName)
        } else {
            Write-Log "ADD: $modName"
            
            try {
                $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $modUrl -OutFile $remotePath -UseBasicParsing -ErrorAction Stop
                $added++
                $script:modChanges += @{ Action = "ADD"; FileName = $modName }
            } catch {
                Write-Log "ERROR downloading $modName : $_" "ERROR"
                $errors++
            }
        }
    }
    
    foreach ($modName in $remoteMods.Keys) {
        Write-Log "REMOVE: $modName"
        try {
            Remove-Item (Join-Path $RemoteModsPath $modName) -Force
            $removed++
            $script:modChanges += @{ Action = "REMOVE"; FileName = $modName }
        } catch {
            Write-Log "ERROR removing $modName : $_" "ERROR"
            $errors++
        }
    }
    
    Write-Log ""
    Write-Log "========== SUMMARY =========="
    Write-Log "Added:   $added"
    Write-Log "Updated: $updated"
    Write-Log "Removed: $removed"
    Write-Log "Errors:  $errors"
    Write-Log "============================"
    
    return @{ Added = $added; Updated = $updated; Removed = $removed; Errors = $errors }
}

function Test-GitRepository {
    if (-not $GitEnabled) {
        return $false
    }
    
    if (-not (Test-Path "$GitRepoPath\.git")) {
        Write-Log "Git repository not initialized at $GitRepoPath" "WARN"
        return $false
    }
    
    return $true
}

function Update-Changelog {
    param(
        [object]$LatestVersion,
        [hashtable]$SyncResult,
        [array]$ModChanges
    )
    
    if (-not (Test-Path $ChangelogPath)) {
        Write-Log "Changelog file not found at $ChangelogPath" "WARN"
        return $false
    }
    
    try {
        Write-Log "Updating changelog..."
        
        # Read current changelog
        $changelogContent = Get-Content $ChangelogPath -Raw
        
        # Generate version entry
        $versionDate = Get-Date -Format "yyyy-MM-dd"
        $versionNumber = $LatestVersion.version_number
        
        $changelogEntry = @"

### $versionNumber - $versionDate

**Modpack Update:**
- Synced from Modrinth modpack version $versionNumber
- Changes: $($SyncResult.Added) added, $($SyncResult.Updated) updated, $($SyncResult.Removed) removed

"@
        
        # Add mod details if there are changes
        if ($ModChanges.Count -gt 0) {
            $addedMods = $ModChanges | Where-Object { $_.Action -eq "ADD" }
            $updatedMods = $ModChanges | Where-Object { $_.Action -eq "UPDATE" }
            $removedMods = $ModChanges | Where-Object { $_.Action -eq "REMOVE" }
            
            if ($addedMods.Count -gt 0) {
                $changelogEntry += "`n**Added Mods:**`n"
                foreach ($mod in $addedMods) {
                    $changelogEntry += "- $($mod.FileName)`n"
                }
            }
            
            if ($updatedMods.Count -gt 0) {
                $changelogEntry += "`n**Updated Mods:**`n"
                foreach ($mod in $updatedMods) {
                    $changelogEntry += "- $($mod.FileName)`n"
                }
            }
            
            if ($removedMods.Count -gt 0) {
                $changelogEntry += "`n**Removed Mods:**`n"
                foreach ($mod in $removedMods) {
                    $changelogEntry += "- $($mod.FileName)`n"
                }
            }
        }
        
        # Insert new entry after "## Modpack Version History" header
        if ($changelogContent -match "(?s)(## Modpack Version History)(.*)") {
            $newContent = $changelogContent -replace "(## Modpack Version History)", "`$1$changelogEntry"
            Set-Content -Path $ChangelogPath -Value $newContent -NoNewline
            Write-Log "Changelog updated successfully"
            return $true
        } else {
            Write-Log "Could not find 'Modpack Version History' section in changelog" "WARN"
            return $false
        }
        
    } catch {
        Write-Log "Failed to update changelog: $_" "ERROR"
        return $false
    }
}

function Invoke-GitCommit {
    param(
        [string]$Message,
        [string[]]$FilesToCommit
    )
    
    if (-not (Test-GitRepository)) {
        return $false
    }
    
    try {
        Push-Location $GitRepoPath
        
        # Check if there are changes
        $status = & git status --porcelain 2>&1
        if (-not $status) {
            Write-Log "No git changes to commit"
            return $true
        }
        
        # Stage files
        foreach ($file in $FilesToCommit) {
            $relativePath = $file.Replace("$GitRepoPath\", "").Replace("\", "/")
            Write-Log "Staging file: $relativePath"
            & git add $relativePath 2>&1 | Out-Null
        }
        
        # Check if there are staged changes
        $stagedChanges = & git diff --cached --name-only 2>&1
        if (-not $stagedChanges) {
            Write-Log "No changes staged for commit"
            return $true
        }
        
        # Commit
        Write-Log "Committing changes: $Message"
        $commitOutput = & git commit -m $Message 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Git commit successful"
            return $true
        } else {
            Write-Log "Git commit failed: $commitOutput" "WARN"
            return $false
        }
        
    } catch {
        Write-Log "Git commit error: $_" "ERROR"
        return $false
    } finally {
        Pop-Location
    }
}

function Invoke-GitPush {
    if (-not (Test-GitRepository)) {
        return $false
    }
    
    try {
        Push-Location $GitRepoPath
        
        Write-Log "Pushing to remote: $GitRemoteName/$GitBranch"
        $pushOutput = & git push $GitRemoteName $GitBranch 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Git push successful"
            return $true
        } else {
            Write-Log "Git push failed: $pushOutput" "WARN"
            Write-Log "You may need to manually push changes or configure git credentials" "WARN"
            return $false
        }
        
    } catch {
        Write-Log "Git push error: $_" "ERROR"
        return $false
    } finally {
        Pop-Location
    }
}

# Main execution
try {
    Initialize
    
    $packInfo = Get-ModrinthPackInfo
    $latestVersion = Get-LatestPackVersion -PackInfo $packInfo
    
    if (-not $ForceUpdate) {
        if (-not (Test-UpdateNeeded -LatestVersion $latestVersion)) {
            if ($CheckOnly) {
                Write-Log "Check complete - no update available"
            } else {
                Write-Log "Exiting - no update needed"
            }
            exit 0
        }
    } else {
        Write-Log "ForceUpdate flag set - proceeding with sync"
    }
    
    if ($CheckOnly) {
        Write-Log "Update available - would sync on next scheduled run"
        exit 0
    }
    
    $mrpackFile = Download-Mrpack -Version $latestVersion
    $manifest = Extract-Manifest -MrpackFile $mrpackFile
    $whitelist = Get-ServerModsWhitelist
    $matchedMods = Get-MatchingMods -Manifest $manifest -Whitelist $whitelist
    
    $syncResult = Sync-Mods -MatchedMods $matchedMods
    
    Save-VersionCache -LatestVersion $latestVersion
    
    if ($syncResult.Added -gt 0 -or $syncResult.Updated -gt 0 -or $syncResult.Removed -gt 0) {
        Write-Log "Mod changes detected - server restart recommended"
        
        # Update changelog and commit to git if enabled
        if ($GitEnabled -and $GitAutoCommit) {
            Write-Log ""
            Write-Log "========== GIT INTEGRATION =========="
            
            $changelogUpdated = Update-Changelog -LatestVersion $latestVersion -SyncResult $syncResult -ModChanges $script:modChanges
            
            if ($changelogUpdated) {
                $commitMessage = "Auto-sync: Modpack $($latestVersion.version_number) - $($syncResult.Added) added, $($syncResult.Updated) updated, $($syncResult.Removed) removed"
                $filesToCommit = @($ChangelogPath)
                
                $committed = Invoke-GitCommit -Message $commitMessage -FilesToCommit $filesToCommit
                
                if ($committed -and $GitAutoPush) {
                    $pushed = Invoke-GitPush
                    if ($pushed) {
                        Write-Log "Changelog pushed to remote repository"
                    } else {
                        Write-Log "Changelog committed locally - manual push required" "WARN"
                    }
                }
            }
            
            Write-Log "====================================="
        }
    } else {
        Write-Log "No mod changes - server restart not needed"
    }
    
    Write-Log "Sync completed successfully"
    Write-Log "Log: $LogFile"
    
} catch {
    Write-Log "FATAL ERROR: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    exit 1
} finally {
    if (Test-Path $TempExtractPath) {
        Remove-Item $TempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    if (Test-Path "$env:TEMP\temp_download.mrpack") {
        Remove-Item "$env:TEMP\temp_download.mrpack" -Force -ErrorAction SilentlyContinue
    }
}
