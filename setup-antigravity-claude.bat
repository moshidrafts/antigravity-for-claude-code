<# :
@echo off
title Antigravity Protocol Suite for Claude (Setup)
cls
set "ANTIGRAVITY_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$scriptDir = $env:ANTIGRAVITY_DIR.TrimEnd('\'); Invoke-Expression (Get-Content -Raw '%~f0')"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Setup encountered an unexpected error.
    pause
)
exit /b %ERRORLEVEL%
: #>

$ErrorActionPreference = "Stop"

Clear-Host
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "               ANTIGRAVITY PROTOCOL SUITE FOR CLAUDE                      " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$userProfile = [System.Environment]::GetFolderPath('UserProfile')
$claudeDir = Join-Path $userProfile ".claude"
$skillsDir = Join-Path $claudeDir "skills"
$agentsDir = Join-Path $claudeDir "agents"
$outputStylesDir = Join-Path $claudeDir "output-styles"
$catalogDir = Join-Path $claudeDir "skills-catalog"
$binDir = Join-Path $claudeDir "bin"

if (-not $scriptDir) {
    if ($env:ANTIGRAVITY_DIR) {
        $scriptDir = $env:ANTIGRAVITY_DIR.TrimEnd('\')
    } elseif ($PSScriptRoot) {
        $scriptDir = $PSScriptRoot
    } else {
        $scriptDir = (Get-Location).Path
    }
}
$localSkills = Join-Path $scriptDir "skills"
$localAgents = Join-Path $scriptDir "agents"
$localOutputStyles = Join-Path $scriptDir "output-styles"

# 1. Directories
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null
New-Item -ItemType Directory -Force -Path $outputStylesDir | Out-Null
New-Item -ItemType Directory -Force -Path $catalogDir | Out-Null
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

# 2. Deploy Skills, Catalog, Subagents & Output Styles (clean up retired legacy skills on upgrade)
Write-Host "`n[1/6] Deploying 12 skills, 2 subagents, and Simple English style to $claudeDir..." -ForegroundColor Yellow -NoNewline
$disabledDir = Join-Path $claudeDir "skills-disabled"
foreach ($legacySkill in @("antigravity", "antigravity-planner", "neural-context")) {
    foreach ($base in @($skillsDir, $catalogDir, $disabledDir)) {
        $legacyPath = Join-Path $base $legacySkill
        if (Test-Path $legacyPath) { Remove-Item -Path $legacyPath -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
$legacyBat = Join-Path $binDir "neural-context.bat"
$legacyDb = Join-Path $claudeDir "neural_memory.db"
if (Test-Path $legacyBat) { Remove-Item -Path $legacyBat -Force -ErrorAction SilentlyContinue }
if (Test-Path $legacyDb) { Remove-Item -Path $legacyDb -Force -ErrorAction SilentlyContinue }
if (Test-Path $localSkills) {
    Get-ChildItem -Path $localSkills -Directory | ForEach-Object {
        $target = Join-Path $skillsDir $_.Name
        $catTarget = Join-Path $catalogDir $_.Name
        Copy-Item -Path $_.FullName -Destination $target -Recurse -Force
        Copy-Item -Path $_.FullName -Destination $catTarget -Recurse -Force
    }
}
if (Test-Path $localAgents) {
    Get-ChildItem -Path $localAgents -Filter "*.md" -File | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $agentsDir $_.Name) -Force
    }
}
if (Test-Path $localOutputStyles) {
    Get-ChildItem -Path $localOutputStyles -Filter "*.md" -File | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $outputStylesDir $_.Name) -Force
    }
}
Write-Host " [DONE]" -ForegroundColor Green

# 3. Global CLAUDE.md Handling (Conflict Resolution: Overwrite / Keep / Append / Cancel)
Write-Host "[2/6] Configuring global CLAUDE.md..." -ForegroundColor Yellow
$claudeMdSource = Join-Path $scriptDir "CLAUDE.md"
$claudeMdDest = Join-Path $claudeDir "CLAUDE.md"

if (Test-Path $claudeMdDest) {
    $existingContent = Get-Content $claudeMdDest -Raw
    $sourceContent = Get-Content $claudeMdSource -Raw
    if ($existingContent -eq $sourceContent) {
        Write-Host "  -> Global CLAUDE.md is already up to date." -ForegroundColor Green
    } else {
        $isExistingAntigravity = ($existingContent -like "*ANTIGRAVITY OPERATING SYSTEM DIRECTIVE*")
        Write-Host "`n  [!] An existing CLAUDE.md was detected at: $claudeMdDest" -ForegroundColor Magenta
        if ($isExistingAntigravity) {
            Write-Host "      It differs from the repo copy (you may have customized it)." -ForegroundColor Gray
        }
        Write-Host "      How would you like to handle this?" -ForegroundColor Yellow
        Write-Host "      [O] Overwrite (backs up existing file to CLAUDE.md.bak)" -ForegroundColor White
        Write-Host "      [K] Keep existing CLAUDE.md untouched" -ForegroundColor White
        if (-not $isExistingAntigravity) {
            Write-Host "      [A] Append Antigravity Protocol to the end of existing file" -ForegroundColor White
        }
        Write-Host "      [C] Cancel / Exit setup without modifying CLAUDE.md" -ForegroundColor White

        $allowedPattern = if ($isExistingAntigravity) { '^[OKC]$' } else { '^[OKAC]$' }
        $promptLabel = if ($isExistingAntigravity) { "O/K/C" } else { "O/K/A/C" }
        $mdChoice = ""
        while ($mdChoice -notmatch $allowedPattern) {
            Write-Host -NoNewline "      Select an option ($promptLabel): " -ForegroundColor Yellow
            $rawInput = Read-Host
            if ($rawInput -eq $null) {
                $mdChoice = if ($isExistingAntigravity) { 'K' } else { 'O' }
                break
            }
            $mdChoice = $rawInput.Trim().ToUpper()
        }

        if ($mdChoice -eq 'C') {
            Write-Host "`nSetup cancelled. No modifications were made to CLAUDE.md." -ForegroundColor Yellow
            exit 0
        } elseif ($mdChoice -eq 'K') {
            Write-Host "  -> Kept your existing CLAUDE.md untouched." -ForegroundColor Green
        } elseif ($mdChoice -eq 'A') {
            Copy-Item $claudeMdDest "$claudeMdDest.bak" -Force
            $merged = $existingContent + "`n`n" + $sourceContent
            [System.IO.File]::WriteAllText($claudeMdDest, $merged, [System.Text.Encoding]::UTF8)
            Write-Host "  -> Antigravity appended to existing CLAUDE.md (backup: CLAUDE.md.bak)" -ForegroundColor Green
        } elseif ($mdChoice -eq 'O') {
            Copy-Item $claudeMdDest "$claudeMdDest.bak" -Force
            Copy-Item $claudeMdSource $claudeMdDest -Force
            Write-Host "  -> CLAUDE.md overwritten (original backed up to CLAUDE.md.bak)" -ForegroundColor Green
        }
    }
} else {
    Copy-Item $claudeMdSource $claudeMdDest -Force
    Write-Host "  -> Global CLAUDE.md deployed successfully." -ForegroundColor Green
}

# 4. Prompt Caching, Output Style, Advisor & Native Settings
Write-Host "[3/6] Configuring 1h caching, Simple English style & native settings..." -ForegroundColor Yellow -NoNewline
[System.Environment]::SetEnvironmentVariable('ENABLE_PROMPT_CACHING_1H', '1', 'User')
$env:ENABLE_PROMPT_CACHING_1H = '1'
$settingsJsonPath = Join-Path $claudeDir "settings.json"
try {
    $cCfg = if (Test-Path $settingsJsonPath) {
        $rawCfg = Get-Content $settingsJsonPath -Raw
        if ([string]::IsNullOrWhiteSpace($rawCfg)) { [pscustomobject]@{} } else { $rawCfg | ConvertFrom-Json }
    } else {
        [pscustomobject]@{}
    }
    $cCfg | Add-Member -NotePropertyName "promptCacheTtl" -NotePropertyValue "1h" -Force
    $cCfg | Add-Member -NotePropertyName "subagentPromptCacheTtl" -NotePropertyValue "1h" -Force
    $cCfg | Add-Member -NotePropertyName "outputStyle" -NotePropertyValue "Simple English" -Force
    $cCfg | Add-Member -NotePropertyName "advisorModel" -NotePropertyValue "fable" -Force
    $cCfg | Add-Member -NotePropertyName "inputNeededNotifEnabled" -NotePropertyValue $true -Force
    $cCfg | Add-Member -NotePropertyName "agentPushNotifEnabled" -NotePropertyValue $true -Force
    if (-not $cCfg.extraKnownMarketplaces) {
        $cCfg | Add-Member -NotePropertyName "extraKnownMarketplaces" -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    if (-not $cCfg.extraKnownMarketplaces.PSObject.Properties["centminmod"]) {
        $cCfg.extraKnownMarketplaces | Add-Member -NotePropertyName "centminmod" -NotePropertyValue ([pscustomobject]@{ source = [pscustomobject]@{ source = "github"; repo = "centminmod/claude-plugins" } }) -Force
    }
    if (-not $cCfg.extraKnownMarketplaces.PSObject.Properties["claude-community"]) {
        $cCfg.extraKnownMarketplaces | Add-Member -NotePropertyName "claude-community" -NotePropertyValue ([pscustomobject]@{ source = [pscustomobject]@{ source = "github"; repo = "anthropics/claude-plugins-community" } }) -Force
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($settingsJsonPath, ($cCfg | ConvertTo-Json -Depth 10), $utf8NoBom)
} catch {}
Write-Host " [DONE]" -ForegroundColor Green

# 5. Global CLI Commands (agy-settings & antigravity-settings in PATH)
Write-Host "[4/6] Registering global 'agy-settings' command in PATH..." -ForegroundColor Yellow -NoNewline
$settingsPs1Source = Join-Path $scriptDir "scripts\settings.ps1"
$settingsPs1Dest = Join-Path $binDir "settings.ps1"
Copy-Item $settingsPs1Source $settingsPs1Dest -Force

$agyBatContent = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0settings.ps1`""
Set-Content -Path (Join-Path $binDir "agy-settings.bat") -Value $agyBatContent
Set-Content -Path (Join-Path $binDir "antigravity-settings.bat") -Value $agyBatContent

$userPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -notlike "*$binDir*") {
    $newUserPath = "$userPath;$binDir"
    [System.Environment]::SetEnvironmentVariable('PATH', $newUserPath, 'User')
}
if ($env:PATH -notlike "*$binDir*") {
    $env:PATH = "$env:PATH;$binDir"
}
Write-Host " [DONE]" -ForegroundColor Green

# 6. Default Config JSON (create or strip retired keys on upgrade)
$configFile = Join-Path $claudeDir "antigravity.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
if (-not (Test-Path $configFile)) {
    $cfg = [ordered]@{
        prompt_caching_1h = $true
        rtk_proxy = $true
        graphify = $true
        skills = [ordered]@{
            "caveman" = $true
            "graphify" = $true
            "session-metrics" = $true
            "session-report" = $true
            "frontend-design" = $true
            "test-driven-development" = $true
            "systematic-debugging" = $true
            "verification-before-completion" = $true
            "web-artifacts-builder" = $true
            "xlsx" = $true
            "pdf" = $true
            "docx" = $true
        }
    }
    [System.IO.File]::WriteAllText($configFile, ($cfg | ConvertTo-Json -Depth 5), $utf8NoBom)
} else {
    try {
        $existingCfg = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($existingCfg.skills) {
            $changed = $false
            foreach ($stale in @("antigravity", "antigravity-planner", "neural-context")) {
                if ($existingCfg.skills.PSObject.Properties[$stale]) {
                    $existingCfg.skills.PSObject.Properties.Remove($stale)
                    $changed = $true
                }
            }
            if ($changed) {
                [System.IO.File]::WriteAllText($configFile, ($existingCfg | ConvertTo-Json -Depth 5), $utf8NoBom)
            }
        }
    } catch {}
}

# 7. Configure Vetted Developer Plugins & Compiler LSPs (if Claude CLI is present)
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    Write-Host "[5/6] Registering Vetted Developer Plugins & Compiler LSPs..." -ForegroundColor Yellow
    try {
        $recommendedPlugins = @(
            "pyright-lsp@claude-plugins-official",
            "typescript-lsp@claude-plugins-official",
            "code-review@claude-plugins-official",
            "code-simplifier@claude-plugins-official",
            "commit-commands@claude-plugins-official",
            "skill-creator@claude-plugins-official",
            "claude-security@claude-plugins-official",
            "mcp-server-dev@claude-plugins-official",
            "mcp-tunnels@claude-plugins-official",
            "agent-sdk-dev@claude-plugins-official"
        )
        foreach ($p in $recommendedPlugins) {
            & claude plugin install $p 2>&1 | Out-Null
        }
        Write-Host "  -> Vetted developer plugins & compiler LSPs configured (clean, zero colon spam)." -ForegroundColor Green
    } catch {
        Write-Host "  -> Plugin configuration skipped." -ForegroundColor DarkGray
    }
}

# 8. Instructions Copy with Safety
$instructions = @"
# ANTIGRAVITY OPERATING SYSTEM DIRECTIVE

High-signal engineering discipline:
- Omit conversational fluff, preambles, and sign-offs. Answer directly.
- Read target files, callers, and shared contracts before editing. Keep edits targeted.
- For complex or multi-file work, map dependencies and surface ripple impacts before coding.
- Verify fixes by running relevant tests, linters, or builds; never claim completion without observed results.
- Never dump 400-line files for small changes; use targeted chunks or diffs.
"@

try {
    Set-Clipboard -Value $instructions
    Write-Host "[6/6] Copying Custom Instructions to Windows Clipboard... [COPIED]" -ForegroundColor Green
} catch {
    Write-Host "[6/6] Copying Custom Instructions to Windows Clipboard... [MANUAL COPY]" -ForegroundColor Yellow
}

# -------------------------------------------------------------
# STEP 1: DISPLAY CUSTOM INSTRUCTIONS
# -------------------------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "           1. CLAUDE DESKTOP CUSTOM INSTRUCTIONS (IN CLIPBOARD!)          " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host @"
+------------------------------------------------------------------------+
|                                                                        |
|  * ZERO CONVERSATIONAL FLUFF (Immediate engineering answers)           |
|  * READ BEFORE EDITING & RIPPLE CHECK (Trace callers first)            |
|  * NATIVE PLAN MODE & SUBAGENTS (No junk .md files in repo roots)      |
|  * VERIFY BEFORE COMPLETION (Run tests/builds before claiming done)    |
|  * TARGETED CHUNK DIFFS (Never dump entire files)                      |
|                                                                        |
+------------------------------------------------------------------------+
"@ -ForegroundColor Yellow

# -------------------------------------------------------------
# STEP 2: WHAT TO DO NEXT
# -------------------------------------------------------------
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "                      2. WHAT TO DO NEXT                                  " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  1. Open Claude Desktop (or Claude.ai web)." -ForegroundColor White
Write-Host "  2. Go to: Settings -> Custom Instructions." -ForegroundColor White
Write-Host "  3. Press Ctrl + V to paste the copied instructions." -ForegroundColor White
Write-Host "  4. Click Save." -ForegroundColor White
Write-Host "  5. Start coding in Claude Desktop's Code tab (or run 'claude' in your terminal)!" -ForegroundColor White

# -------------------------------------------------------------
# STEP 3: SETTINGS & CUSTOMIZATION
# -------------------------------------------------------------
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "                    3. SETTINGS & GLOBAL COMMAND                          " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "  * All 12 skills, 2 subagents, and 1-hour caching are ENABLED by default." -ForegroundColor Green
Write-Host "  * You can now run 'agy-settings' from ANY terminal on your computer!" -ForegroundColor Yellow
Write-Host "  * Or run 'settings.bat' right here in this folder." -ForegroundColor Gray
Write-Host "==========================================================================" -ForegroundColor Cyan

Write-Host "`nPress [S] to open Settings now, or press Enter to finish: " -ForegroundColor Yellow -NoNewline
$opt = Read-Host
if ($opt -eq 's' -or $opt -eq 'S') {
    & "$binDir\settings.ps1"
} else {
    Write-Host "`nInstallation complete! Enjoy Antigravity for Claude.`n" -ForegroundColor Green
}
