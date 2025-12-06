# Helper script to convert filename-based whitelist to project ID-based whitelist
# Run this once to generate the new server-mods.txt

$ModrinthApiBase = "https://api.modrinth.com/v2"
$ModrinthPackSlug = "wolfs-den-4"
$ServerModsListPath = "Z:\Instances\WolfsDen401\Minecraft\scripts\server-mods.txt"
$TempExtractPath = "$env:TEMP\mrpack_convert"
$OutputPath = "Z:\Instances\WolfsDen401\Minecraft\scripts\server-mods-new.txt"

Write-Host "Fetching pack info from Modrinth..."
$packInfo = Invoke-RestMethod -Uri "$ModrinthApiBase/project/$ModrinthPackSlug" -UseBasicParsing
$versionsUrl = "$ModrinthApiBase/project/$($packInfo.id)/version"
$versions = Invoke-RestMethod -Uri $versionsUrl -UseBasicParsing
$latestVersion = $versions[0]

Write-Host "Downloading latest modpack ($($latestVersion.version_number))..."
$mrpackFile = $latestVersion.files | Where-Object { $_.filename -like "*.mrpack" } | Select-Object -First 1
$tempMrpack = "$env:TEMP\temp_convert.mrpack"
Invoke-WebRequest -Uri $mrpackFile.url -OutFile $tempMrpack -UseBasicParsing

Write-Host "Extracting manifest..."
if (Test-Path $TempExtractPath) { Remove-Item $TempExtractPath -Recurse -Force }
New-Item -ItemType Directory $TempExtractPath | Out-Null
$tempZip = "$TempExtractPath\temp.zip"
Copy-Item $tempMrpack $tempZip
Expand-Archive -Path $tempZip -DestinationPath $TempExtractPath -Force

$manifestPath = "$TempExtractPath\modrinth.index.json"
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

Write-Host "Loading current whitelist..."
$currentMods = @{}
Get-Content $ServerModsListPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $currentMods[$line] = $true
    }
}

Write-Host "`nCurrent whitelist: $($currentMods.Count) mods"
Write-Host "Manifest contains: $($manifest.files.Count) total mods"

Write-Host "`nExtracting project IDs for whitelisted mods..."
$projectIdMap = @()
$notFound = @()

foreach ($file in $manifest.files) {
    $fileName = Split-Path $file.path -Leaf
    
    if ($currentMods.ContainsKey($fileName)) {
        # Extract project ID from URL: https://cdn.modrinth.com/data/PROJECT_ID/versions/...
        $url = $file.downloads[0]
        if ($url -match '/data/([^/]+)/') {
            $projectId = $matches[1]
            $projectIdMap += [PSCustomObject]@{
                FileName = $fileName
                ProjectId = $projectId
            }
        } else {
            $notFound += $fileName
        }
    }
}

Write-Host "Matched: $($projectIdMap.Count) mods"
Write-Host "Not found in manifest: $($currentMods.Count - $projectIdMap.Count) mods"

if ($notFound.Count -gt 0) {
    Write-Host "`nMods in whitelist but not found in manifest:"
    $notFound | ForEach-Object { Write-Host "  - $_" }
}

Write-Host "`nGenerating new whitelist with project IDs..."
$output = @()
$output += "# Wolf's Den 4 - Server Mods Whitelist (Project IDs)"
$output += "# Format: project-id  # Mod Name"
$output += "# This file is version-independent - mod filenames can change without updating this list"
$output += ""

$projectIdMap | Sort-Object FileName | ForEach-Object {
    $modName = $_.FileName -replace '-\d+\..*\.jar$', ''  # Strip version and .jar
    $output += "$($_.ProjectId)  # $modName"
}

$output | Out-File $OutputPath -Encoding UTF8

Write-Host "`nNew whitelist written to: $OutputPath"
Write-Host "Total project IDs: $($projectIdMap.Count)"
Write-Host "`nNext steps:"
Write-Host "1. Review $OutputPath"
Write-Host "2. Backup old server-mods.txt"
Write-Host "3. Replace server-mods.txt with new version"
Write-Host "4. Update Sync-Mods-Modrinth.ps1 to use project IDs"

# Cleanup
Remove-Item $TempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $tempMrpack -Force -ErrorAction SilentlyContinue

Write-Host "`nDone!"
