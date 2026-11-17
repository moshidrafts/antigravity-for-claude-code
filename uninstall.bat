<# :
@echo off
title Uninstall Antigravity Suite
cls
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression (Get-Content -Raw '%~f0')"
pause
exit /b %ERRORLEVEL%
: #>

$ErrorActionPreference = "Continue"

Write-Host "==========================================================================" -ForegroundColor Red
Write-Host "             UNINSTALL ANTIGRAVITY PROTOCOL SUITE                         " -ForegroundColor Red
Write-Host "==========================================================================" -ForegroundColor Red
Write-Host "`nThis will safely remove Antigravity skills, configuration, and prompt caching." -ForegroundColor Yellow
Write-Host "(Your personal custom skills outside this suite will NOT be touched)`n" -ForegroundColor Gray

Write-Host -NoNewline "Are you sure you want to proceed? (y/N): " -ForegroundColor Red
$confirm = Read-Host

if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "`nUninstall cancelled." -ForegroundColor Green
    return
}

$userProfile = [System.Environment]::GetFolderPath('UserProfile')
$claudeDir = Join-Path $userProfile ".claude"
$skillsDir = Join-Path $claudeDir "skills"
$disabledDir = Join-Path $claudeDir "skills-disabled"
$catalogDir = Join-Path $claudeDir "skills-catalog"
$binDir = Join-Path $claudeDir "bin"

$skillsToRemove = @(
    "antigravity",
    "antigravity-planner",
    "neural-context",
    "caveman",
    "session-metrics",
    "session-report",
    "graphify",
    "frontend-design",
    "test-driven-development",
    "systematic-debugging",
    "verification-before-completion",
    "web-artifacts-builder",
    "xlsx",
    "pdf",
    "docx"
)

$agentsToRemove = @("architect.md", "verifier.md")
$agentsDir = Join-Path $claudeDir "agents"

Write-Host "`n[1/5] Removing Antigravity skills, subagents, and catalog..." -ForegroundColor Cyan
foreach ($s in $skillsToRemove) {
    $p1 = Join-Path $skillsDir $s
    $p2 = Join-Path $disabledDir $s
    $p3 = Join-Path $catalogDir $s
    if (Test-Path $p1) { Remove-Item -Path $p1 -Recurse -Force; Write-Host "  -> Removed: $s" -ForegroundColor Gray }
    if (Test-Path $p2) { Remove-Item -Path $p2 -Recurse -Force; Write-Host "  -> Removed disabled: $s" -ForegroundColor Gray }
    if (Test-Path $p3) { Remove-Item -Path $p3 -Recurse -Force }
}
foreach ($ag in $agentsToRemove) {
    $ap = Join-Path $agentsDir $ag
    if (Test-Path $ap) { Remove-Item -Path $ap -Force; Write-Host "  -> Removed subagent: $ag" -ForegroundColor Gray }
}
$simpleEnglishStyle = Join-Path $claudeDir "output-styles\simple-english.md"
if (Test-Path $simpleEnglishStyle) {
    Remove-Item -Path $simpleEnglishStyle -Force
    Write-Host "  -> Removed output style: simple-english.md" -ForegroundColor Gray
}
if (Test-Path $catalogDir) { Remove-Item -Path $catalogDir -Recurse -Force }

Write-Host "`n[2/5] Restoring CLAUDE.md..." -ForegroundColor Cyan
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
$claudeBak = Join-Path $claudeDir "CLAUDE.md.bak"

if (Test-Path $claudeBak) {
    Move-Item $claudeBak $claudeMd -Force
    Write-Host "  -> Restored original CLAUDE.md from backup." -ForegroundColor Green
} elseif (Test-Path $claudeMd) {
    $content = Get-Content $claudeMd -Raw
    if ($content -like "*ANTIGRAVITY OPERATING SYSTEM DIRECTIVE*") {
        Remove-Item $claudeMd -Force
        Write-Host "  -> Removed Antigravity CLAUDE.md." -ForegroundColor Green
    } else {
        Write-Host "  -> Custom CLAUDE.md preserved." -ForegroundColor Yellow
    }
}

Write-Host "`n[3/5] Cleaning up RTK hooks & files..." -ForegroundColor Cyan
$rtkMd = Join-Path $claudeDir "RTK.md"
if (Test-Path $rtkMd) { Remove-Item $rtkMd -Force }

$settingsJson = Join-Path $claudeDir "settings.json"
if (Test-Path $settingsJson) {
    try {
        $rawCfg = Get-Content $settingsJson -Raw
        if (-not [string]::IsNullOrWhiteSpace($rawCfg)) {
            $cCfg = $rawCfg | ConvertFrom-Json
            $modified = $false
            if ($cCfg.hooks -and $cCfg.hooks.PreToolUse) {
                $remainingPre = @($cCfg.hooks.PreToolUse | Where-Object {
                    -not ($_.hooks -and ($_.hooks | Where-Object { $_.command -like "*rtk hook claude*" }))
                })
                if ($remainingPre.Count -ne @($cCfg.hooks.PreToolUse).Count) {
                    $modified = $true
                    if ($remainingPre.Count -gt 0) {
                        $cCfg.hooks.PreToolUse = $remainingPre
                    } else {
                        $cCfg.hooks.PSObject.Properties.Remove("PreToolUse")
                    }
                    if (($cCfg.hooks.PSObject.Properties | Measure-Object).Count -eq 0) {
                        $cCfg.PSObject.Properties.Remove("hooks")
                    }
                    Write-Host "  -> Removed RTK hook from settings.json (preserved custom hooks)." -ForegroundColor Green
                }
            }
            if ($cCfg.PSObject.Properties["promptCacheTtl"]) {
                $cCfg.PSObject.Properties.Remove("promptCacheTtl")
                $modified = $true
            }
            if ($cCfg.PSObject.Properties["subagentPromptCacheTtl"]) {
                $cCfg.PSObject.Properties.Remove("subagentPromptCacheTtl")
                $modified = $true
            }
            if ($cCfg.outputStyle -eq "Simple English") {
                $cCfg.PSObject.Properties.Remove("outputStyle")
                $modified = $true
            }
            if ($cCfg.advisorModel -eq "fable") {
                $cCfg.PSObject.Properties.Remove("advisorModel")
                $modified = $true
            }
            if ($modified) {
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($settingsJson, ($cCfg | ConvertTo-Json -Depth 10), $utf8NoBom)
            }
        }
    } catch {}
}

# Remove global command launchers & settings
$agyBat = Join-Path $binDir "agy-settings.bat"
$antigravityBat = Join-Path $binDir "antigravity-settings.bat"
$settingsPs1 = Join-Path $binDir "settings.ps1"
$neuralBat = Join-Path $binDir "neural-context.bat"
if (Test-Path $agyBat) { Remove-Item $agyBat -Force }
if (Test-Path $antigravityBat) { Remove-Item $antigravityBat -Force }
if (Test-Path $settingsPs1) { Remove-Item $settingsPs1 -Force }
if (Test-Path $neuralBat) { Remove-Item $neuralBat -Force }

Write-Host "`n[4/5] Removing Prompt Caching Environment Variable..." -ForegroundColor Cyan
[System.Environment]::SetEnvironmentVariable('ENABLE_PROMPT_CACHING_1H', $null, 'User')
$env:ENABLE_PROMPT_CACHING_1H = $null
Write-Host "  -> Cleared ENABLE_PROMPT_CACHING_1H." -ForegroundColor Green

Write-Host "`n[5/5] Removing configuration files..." -ForegroundColor Cyan
$cfg = Join-Path $claudeDir "antigravity.json"
if (Test-Path $cfg) { Remove-Item $cfg -Force }

Write-Host "`n==========================================================================" -ForegroundColor Green
Write-Host " [SUCCESS] Antigravity Suite has been cleanly uninstalled.                " -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
