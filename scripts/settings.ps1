# scripts/settings.ps1
# Interactive Settings Manager for Antigravity-Claude Suite

$ErrorActionPreference = "Continue"

$userProfile = [System.Environment]::GetFolderPath('UserProfile')
$claudeDir = Join-Path $userProfile ".claude"
$skillsDir = Join-Path $claudeDir "skills"
$disabledDir = Join-Path $claudeDir "skills-disabled"
$catalogDir = Join-Path $claudeDir "skills-catalog"
$binDir = Join-Path $claudeDir "bin"
$configFile = Join-Path $claudeDir "antigravity.json"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoDir = Split-Path -Parent $scriptDir

if (-not (Test-Path $skillsDir)) { New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null }
if (-not (Test-Path $disabledDir)) { New-Item -ItemType Directory -Force -Path $disabledDir | Out-Null }
if (-not (Test-Path $catalogDir)) { New-Item -ItemType Directory -Force -Path $catalogDir | Out-Null }
if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Force -Path $binDir | Out-Null }

$allSkillNames = @(
    "caveman",
    "session-metrics",
    "session-report",
    "frontend-design",
    "test-driven-development",
    "systematic-debugging",
    "verification-before-completion",
    "web-artifacts-builder",
    "xlsx",
    "pdf",
    "docx"
)

$skillSubtitles = @{
    "caveman"                        = "JuliusBrussee: Ultra-compressed token communication (cuts 60-75% output tokens)"
    "session-metrics"                = "Real-time session token cost timeline, cache efficiency & waste analysis"
    "session-report"                 = "Official Anthropic: Self-contained interactive HTML session dashboard"
    "frontend-design"                = "Anthropic boutique visual design standards (anti-AI slop)"
    "test-driven-development"        = "obra/superpowers: Scoped Red-Green TDD workflow when test-first requested"
    "systematic-debugging"           = "obra/superpowers: 4-phase root cause analysis before fixes"
    "verification-before-completion" = "obra/superpowers: Requires automated test proof before claims"
    "web-artifacts-builder"          = "Anthropic: React 18 + Tailwind + shadcn/ui multi-component apps"
    "xlsx"                           = "Anthropic: Native Excel spreadsheet creation, formulas & data"
    "pdf"                            = "Anthropic: PDF text/table extraction, page merging & OCR"
    "docx"                           = "Anthropic: Word document formatting, styling & template generator"
}

function Wait-KeyPress {
    try {
        if ([System.Console]::IsInputRedirected) {
            $line = Read-Host
            if ($line -eq $null) { return }
        } else {
            $null = [System.Console]::ReadKey($true)
        }
    } catch {
        try {
            $line = Read-Host
            if ($line -eq $null) { return }
        } catch {
            Start-Sleep -Milliseconds 300
        }
    }
}

function Write-JsonNoBom($path, $obj, $depth = 10) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth $depth), $utf8NoBom)
}

function Load-Config {
    if (Test-Path $configFile) {
        try {
            $loaded = Get-Content $configFile -Raw | ConvertFrom-Json
            if ($loaded.skills) {
                foreach ($stale in @("antigravity", "antigravity-planner", "neural-context")) {
                    if ($loaded.skills.PSObject.Properties[$stale]) {
                        $loaded.skills.PSObject.Properties.Remove($stale)
                    }
                }
            }
            return $loaded
        } catch {}
    }
    $cfg = [ordered]@{
        prompt_caching_1h = $true
        rtk_proxy = $true
        graphify = $true
        skills = [ordered]@{}
    }
    foreach ($s in $allSkillNames) {
        $cfg.skills[$s] = $true
    }
    return [pscustomobject]$cfg
}

function Save-Config($cfg) {
    Write-JsonNoBom $configFile $cfg 5
}

function Sync-SkillsToConfig($cfg) {
    foreach ($s in $allSkillNames) {
        $enabledPath = Join-Path $skillsDir $s
        $disabledPath = Join-Path $disabledDir $s
        $catalogPath = Join-Path $catalogDir $s
        $repoPath = Join-Path (Join-Path $repoDir "skills") $s

        $isEnabled = $true
        if ($cfg.skills -and ($cfg.skills.PSObject.Properties[$s])) {
            $isEnabled = [bool]$cfg.skills.$s
        }

        if ($isEnabled) {
            if (-not (Test-Path $enabledPath)) {
                if (Test-Path $disabledPath) {
                    Move-Item -Path $disabledPath -Destination $enabledPath -Force
                } elseif (Test-Path $catalogPath) {
                    Copy-Item -Path $catalogPath -Destination $enabledPath -Recurse -Force
                } elseif (Test-Path $repoPath) {
                    Copy-Item -Path $repoPath -Destination $enabledPath -Recurse -Force
                }
            }
        } else {
            if (Test-Path $enabledPath) {
                Move-Item -Path $enabledPath -Destination $disabledPath -Force
            }
        }
    }
}

function Toggle-Graphify($cfg) {
    $graphifyCmd = Get-Command graphify -ErrorAction SilentlyContinue
    $localExe = Join-Path $binDir "graphify.exe"
    if ((-not $graphifyCmd) -and (-not (Test-Path $localExe))) {
        Write-Host "`nGraphify CLI is not detected. Would you like to install it via pip? (y/N): " -ForegroundColor Yellow -NoNewline
        $raw = Read-Host
        if ($raw -and ($raw.Trim().ToUpper() -eq 'Y')) {
            try {
                Write-Host "Installing graphifyy via pip..." -ForegroundColor Cyan
                & python -m pip install graphifyy --quiet
                $pyScriptPath = & python -c "import sysconfig; print(sysconfig.get_path('scripts'))" 2>$null
                if ($pyScriptPath -and (Test-Path (Join-Path $pyScriptPath "graphify.exe"))) {
                    Copy-Item (Join-Path $pyScriptPath "graphify*.exe") $binDir -Force -ErrorAction SilentlyContinue
                }
                Write-Host "Graphify CLI installed successfully!" -ForegroundColor Green
            } catch {
                Write-Host "Failed to install graphifyy automatically. Run: pip install graphifyy" -ForegroundColor Red
            }
        }
    }

    $newState = (-not [bool]$cfg.graphify)
    $cfg.graphify = $newState
    Save-Config $cfg

    $gSkillSource = Join-Path $catalogDir "graphify"
    $gSkillTarget = Join-Path $skillsDir "graphify"
    $gSkillDisabled = Join-Path $disabledDir "graphify"

    if ($newState) {
        if (Test-Path $gSkillDisabled) {
            Move-Item $gSkillDisabled $gSkillTarget -Force
        } elseif (Test-Path $gSkillSource) {
            Copy-Item $gSkillSource $gSkillTarget -Recurse -Force
        }
        Write-Host "`n[+] Graphify AST Knowledge Graph ENABLED." -ForegroundColor Green
    } else {
        if (Test-Path $gSkillTarget) {
            Move-Item $gSkillTarget $gSkillDisabled -Force
        }
        Write-Host "`n[-] Graphify AST Knowledge Graph DISABLED." -ForegroundColor DarkGray
    }
    Start-Sleep -Seconds 1
}

function Toggle-Skill($name, $cfg) {
    $current = $true
    if ($cfg.skills -and ($cfg.skills.PSObject.Properties[$name])) {
        $current = [bool]$cfg.skills.$name
    }
    $cfg.skills.$name = (-not $current)
    Sync-SkillsToConfig $cfg
    Save-Config $cfg
}

function Toggle-Caching($cfg) {
    $current = [bool]$cfg.prompt_caching_1h
    $newVal = -not $current
    $cfg.prompt_caching_1h = $newVal
    if ($newVal) {
        [System.Environment]::SetEnvironmentVariable('ENABLE_PROMPT_CACHING_1H', '1', 'User')
        $env:ENABLE_PROMPT_CACHING_1H = '1'
    } else {
        [System.Environment]::SetEnvironmentVariable('ENABLE_PROMPT_CACHING_1H', $null, 'User')
        $env:ENABLE_PROMPT_CACHING_1H = $null
    }

    $settingsJson = Join-Path $claudeDir "settings.json"
    try {
        $cCfg = if (Test-Path $settingsJson) {
            $rawCfg = Get-Content $settingsJson -Raw
            if ([string]::IsNullOrWhiteSpace($rawCfg)) { [pscustomobject]@{} } else { $rawCfg | ConvertFrom-Json }
        } else {
            [pscustomobject]@{}
        }
        if ($newVal) {
            $cCfg | Add-Member -NotePropertyName "promptCacheTtl" -NotePropertyValue "1h" -Force
            $cCfg | Add-Member -NotePropertyName "subagentPromptCacheTtl" -NotePropertyValue "1h" -Force
        } else {
            if ($cCfg.PSObject.Properties["promptCacheTtl"]) { $cCfg.PSObject.Properties.Remove("promptCacheTtl") }
            if ($cCfg.PSObject.Properties["subagentPromptCacheTtl"]) { $cCfg.PSObject.Properties.Remove("subagentPromptCacheTtl") }
        }
        Write-JsonNoBom $settingsJson $cCfg 10
    } catch {}

    Save-Config $cfg
}

function Toggle-RTK($cfg) {
    $rtkCmd = Get-Command rtk -ErrorAction SilentlyContinue
    $rtkLocal = Join-Path $binDir "rtk.exe"

    if ((-not $rtkCmd) -and (-not (Test-Path $rtkLocal))) {
        Write-Host "`nRTK is not installed yet. Would you like to install it now? (y/N): " -ForegroundColor Yellow -NoNewline
        $ans = Read-Host
        if ($ans -eq 'y' -or $ans -eq 'Y') {
            $rtkInstaller = Join-Path $scriptDir "install-rtk.ps1"
            if (-not (Test-Path $rtkInstaller)) {
                $rtkInstaller = Join-Path (Join-Path $repoDir "scripts") "install-rtk.ps1"
            }
            if (Test-Path $rtkInstaller) {
                & $rtkInstaller
            } else {
                Write-Host "Could not locate install-rtk.ps1." -ForegroundColor Red
            }
            $cfg.rtk_proxy = $true
            Save-Config $cfg
            Start-Sleep -Seconds 2
        }
        return
    }

    $current = [bool]$cfg.rtk_proxy
    $cfg.rtk_proxy = (-not $current)
    
    $settingsJson = Join-Path $claudeDir "settings.json"
    if (Test-Path $settingsJson) {
        try {
            $rawCfg = Get-Content $settingsJson -Raw
            $cCfg = if ([string]::IsNullOrWhiteSpace($rawCfg)) { [pscustomobject]@{} } else { $rawCfg | ConvertFrom-Json }
            if ($cfg.rtk_proxy) {
                $hookObj = [pscustomobject]@{
                    matcher = "Bash"
                    hooks = @([pscustomobject]@{ type = "command"; command = "rtk hook claude" })
                }
                if (-not $cCfg.hooks) {
                    $cCfg | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([pscustomobject]@{}) -Force
                }
                $existingPre = @()
                if ($cCfg.hooks.PreToolUse) {
                    $existingPre = @($cCfg.hooks.PreToolUse | Where-Object {
                        -not ($_.hooks -and ($_.hooks | Where-Object { $_.command -like "*rtk hook claude*" }))
                    })
                }
                $cCfg.hooks | Add-Member -NotePropertyName "PreToolUse" -NotePropertyValue @($existingPre + $hookObj) -Force
            } else {
                if ($cCfg.hooks -and $cCfg.hooks.PreToolUse) {
                    $remainingPre = @($cCfg.hooks.PreToolUse | Where-Object {
                        -not ($_.hooks -and ($_.hooks | Where-Object { $_.command -like "*rtk hook claude*" }))
                    })
                    if ($remainingPre.Count -gt 0) {
                        $cCfg.hooks.PreToolUse = $remainingPre
                    } else {
                        $cCfg.hooks.PSObject.Properties.Remove("PreToolUse")
                    }
                    if (($cCfg.hooks.PSObject.Properties | Measure-Object).Count -eq 0) {
                        $cCfg.PSObject.Properties.Remove("hooks")
                    }
                }
            }
            Write-JsonNoBom $settingsJson $cCfg 10
        } catch {}
    }
    
    Save-Config $cfg
}

function Show-FeatureGuide {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "               IN-DEPTH FEATURE & SETTINGS GUIDE                          " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host @"
TOKEN OPTIMIZATIONS & COMPANIONS:
--------------------------------------------------------------------------
1. 1-Hour Prompt Caching (settings.json promptCacheTtl="1h" + ENABLE_PROMPT_CACHING_1H=1)
   - What it does: Extends prompt cache TTL from 5m to 1h so long breaks do not
     force full context cache rewrites.
   - Note: 1h cache writes cost 2x vs 5m's 1.25x; best for API / long-idle sessions.

2. RTK (Rust Token Killer)
   - What it does: Lightweight (<10ms) Rust CLI proxy that intercepts terminal
     commands (git, cargo, pytest, npm) and strips out redundant boilerplate,
     empty lines, and progress bars (safely merged into settings.json hooks).
   - Saves: 60% to 90% of bash output tokens from flooding context.

3. Graphify AST Codebase Graph
   - What it does: Uses Tree-sitter to parse your project into a queryable AST
     knowledge graph so Claude navigates symbols directly instead of grepping files.
   - Saves: Eliminates repetitive multi-file search turns on larger repos.

NATIVE SUBAGENTS (~/.claude/agents/):
--------------------------------------------------------------------------
* architect: Read-only Plan Mode dependency & blast-radius analyst.
* verifier:  Isolated test, lint, and build verification worker.

BUNDLED SKILLS DIRECTORY:
--------------------------------------------------------------------------
4. caveman: JuliusBrussee/caveman ultra-compressed communication mode.
   - What it does: Strips articles (a/an/the), filler, hedging, and pleasantries
     while strictly preserving technical terms, code blocks, exact numbers, and errors.
   - Saves: 60% to 75% output tokens on conversational turns without sacrificing accuracy.

5. session-metrics: Real-time token spend, cost timeline, and waste analysis engine.
   - What it does: Runs local python analysis on Claude Code session logs to calculate
     exact USD cost, cache efficiency rates, and anomaly detection. Zero always-on cost.

6. session-report: Official Anthropic interactive HTML session dashboard.
   - What it does: Parses transcripts across ~/.claude/projects and generates a self-contained
     interactive HTML dashboard with sortable tables, token bars, and cache-break heatmaps.

7. frontend-design: Anthropic's official design system preventing 'AI slop'
   (generic purple gradients, boring cards). Enforces boutique studio aesthetics.

8. test-driven-development: Jesse Vincent's obra/superpowers skill. Runs strict
   Red-Green TDD when explicitly requested (/test-driven-development or test-first).

9. systematic-debugging: 4-phase root cause analysis (observe, hypothesize, isolate,
   verify). Eliminates random guessing and symptom-treating hacks.

10. verification-before-completion: Prohibits declaring work 'fixed' or 'complete'
    without executing automated tests or build verification commands first.

11. web-artifacts-builder: Complete multi-component React 18 + Tailwind CSS +
    shadcn/ui application builder for rich interactive side-panel artifacts.

12. xlsx: Official Anthropic skill to manipulate real Excel workbooks (.xlsx),
    compute formulas, build charts, and clean tabular data without corrupting XML.

13. pdf: Official Anthropic skill to extract tables, split/merge pages, rotate,
    decrypt, and perform OCR on scanned PDF files.

14. docx: Official Anthropic skill to create and edit professional Word (.docx)
    documents with custom headings, styles, and tables of contents.
==========================================================================
"@ -ForegroundColor Gray
    Write-Host "`nPress any key to return to settings..." -ForegroundColor Yellow
    Wait-KeyPress
}

function Run-Diagnostics {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                 ANTIGRAVITY SYSTEM DIAGNOSTICS                           " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan

    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        $cVer = (claude --version 2>&1) -join " "
        Write-Host "  [+] Claude Code CLI:       Found ($cVer)" -ForegroundColor Green
    } else {
        Write-Host "  [!] Claude Code CLI:       Not found in PATH" -ForegroundColor Yellow
    }

    $cacheVar = [System.Environment]::GetEnvironmentVariable('ENABLE_PROMPT_CACHING_1H', 'User')
    $settingsJson = Join-Path $claudeDir "settings.json"
    $jsonCacheTtl = $false
    if (Test-Path $settingsJson) {
        try {
            $tmpCfg = Get-Content $settingsJson -Raw | ConvertFrom-Json
            if ($tmpCfg.promptCacheTtl -eq "1h") { $jsonCacheTtl = $true }
        } catch {}
    }
    if ($cacheVar -eq '1' -or $jsonCacheTtl) {
        Write-Host "  [+] 1-Hour Prompt Caching: ACTIVE (settings.json promptCacheTtl=1h / env)" -ForegroundColor Green
    } else {
        Write-Host "  [!] 1-Hour Prompt Caching: INACTIVE" -ForegroundColor DarkGray
    }

    $rtkCmd = Get-Command rtk -ErrorAction SilentlyContinue
    $rtkLocal = Join-Path $binDir "rtk.exe"
    if ($rtkCmd -or (Test-Path $rtkLocal)) {
        $rtkExeTarget = $rtkLocal
        if ($rtkCmd) { $rtkExeTarget = "rtk" }
        $rtkVer = (& $rtkExeTarget --version 2>&1) -join " "
        Write-Host "  [+] RTK Binary:            Installed ($rtkVer)" -ForegroundColor Green
    } else {
        Write-Host "  [!] RTK Binary:            Not installed" -ForegroundColor Yellow
    }

    $settingsJson = Join-Path $claudeDir "settings.json"
    if (Test-Path $settingsJson) {
        $sContent = Get-Content $settingsJson -Raw
        if ($sContent -like "*rtk hook claude*") {
            Write-Host "  [+] Claude RTK Hook:       CONFIGURED in settings.json" -ForegroundColor Green
        } else {
            Write-Host "  [!] Claude RTK Hook:       Not registered in settings.json" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [!] Claude settings.json:  Not found" -ForegroundColor DarkGray
    }

    $claudeMd = Join-Path $claudeDir "CLAUDE.md"
    if (Test-Path $claudeMd) {
        Write-Host "  [+] Global CLAUDE.md:      PRESENT (~/.claude/CLAUDE.md)" -ForegroundColor Green
    } else {
        Write-Host "  [!] Global CLAUDE.md:      MISSING" -ForegroundColor Red
    }

    $activeCount = 0
    $disabledCount = 0
    foreach ($s in $allSkillNames) {
        if (Test-Path (Join-Path $skillsDir $s)) { $activeCount++ }
        if (Test-Path (Join-Path $disabledDir $s)) { $disabledCount++ }
    }
    Write-Host "  [+] Active Skills:         $activeCount of $($allSkillNames.Count) toggled skills (+graphify)" -ForegroundColor Green
    if ($disabledCount -gt 0) {
        Write-Host "  [!] Disabled Skills:       $disabledCount disabled" -ForegroundColor Yellow
    }

    $agentsDir = Join-Path $claudeDir "agents"
    $agentCount = 0
    foreach ($ag in @("architect.md", "verifier.md")) {
        if (Test-Path (Join-Path $agentsDir $ag)) { $agentCount++ }
    }
    Write-Host "  [+] Native Subagents:      $agentCount of 2 installed (architect, verifier)" -ForegroundColor Green

    $marketplacesJson = Join-Path $claudeDir "plugins\known_marketplaces.json"
    if (Test-Path $marketplacesJson) {
        try {
            $mObj = Get-Content $marketplacesJson -Raw | ConvertFrom-Json
            $mCount = ($mObj.PSObject.Properties | Measure-Object).Count
            Write-Host "  [+] Marketplaces:          $mCount registered" -ForegroundColor Green
        } catch {}
    }

    $pluginsJson = Join-Path $claudeDir "plugins\installed_plugins.json"
    if (Test-Path $pluginsJson) {
        try {
            $pObj = Get-Content $pluginsJson -Raw | ConvertFrom-Json
            $pCount = ($pObj.plugins.PSObject.Properties | Measure-Object).Count
            Write-Host "  [+] Claude Code Plugins:   $pCount installed (clean developer suite & compiler LSPs)" -ForegroundColor Green
        } catch {
            Write-Host "  [+] Claude Code Plugins:   Configured" -ForegroundColor Green
        }
    }

    $agyCmd = Get-Command agy-settings -ErrorAction SilentlyContinue
    if ($agyCmd -or (Test-Path (Join-Path $binDir "agy-settings.bat"))) {
        Write-Host "  [+] Global agy-settings:   AVAILABLE ('agy-settings' in any terminal)" -ForegroundColor Green
    } else {
        Write-Host "  [!] Global agy-settings:   Not linked" -ForegroundColor Yellow
    }

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "`nPress any key to return to settings..." -ForegroundColor Yellow
    Wait-KeyPress
}

function Copy-CustomInstructions {
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
        Write-Host "`n[COPIED] Custom Instructions copied to Windows Clipboard!" -ForegroundColor Green
    } catch {
        Write-Host "`n[NOTE] Clipboard unavailable. Please copy instructions from README or CLAUDE.md." -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 2
}

# Main Loop
$cfg = Load-Config
Sync-SkillsToConfig $cfg

while ($true) {
    Clear-Host
    $cachingActive = [bool]$cfg.prompt_caching_1h
    $rtkActive = [bool]$cfg.rtk_proxy
    $graphifyActive = [bool]$cfg.graphify

    $rtkInstalled = (Get-Command rtk -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $binDir "rtk.exe"))

    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "                 ANTIGRAVITY CONFIGURATION & SETTINGS                     " -ForegroundColor Cyan
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "  Toggle token optimizations, CLI proxies, and active skills anytime.      " -ForegroundColor DarkGray
    Write-Host "  (Changes take effect immediately across all Claude sessions)            `n" -ForegroundColor DarkGray

    Write-Host " TOKEN OPTIMIZATIONS & COMPANIONS:" -ForegroundColor Yellow
    
    $cColor = if ($cachingActive) { "Green" } else { "DarkGray" }
    $cText  = if ($cachingActive) { "[ ENABLED  ]" } else { "[ DISABLED ]" }
    Write-Host "  [1] 1-Hour Prompt Caching           $cText" -ForegroundColor $cColor
    Write-Host "      |-- Caches prompts & workspace in RAM for 1h (cuts 90% prompt cost)" -ForegroundColor DarkGray

    $rColor = if ($rtkActive -and $rtkInstalled) { "Green" } elseif ($rtkInstalled) { "DarkGray" } else { "Yellow" }
    $rText  = if (-not $rtkInstalled) { "[ NOT INSTALLED ]" } elseif ($rtkActive) { "[ ENABLED  ]" } else { "[ DISABLED ]" }
    Write-Host "  [2] RTK (Rust Token Killer)          $rText" -ForegroundColor $rColor
    Write-Host "      |-- Strips CLI boilerplate/progress bars from git/npm/tests (60-90% savings)" -ForegroundColor DarkGray

    $gColor = if ($graphifyActive) { "Green" } else { "DarkGray" }
    $gText  = if ($graphifyActive) { "[ ENABLED  ]" } else { "[ DISABLED ]" }
    Write-Host "  [3] Graphify AST Codebase Graph     $gText" -ForegroundColor $gColor
    Write-Host "      |-- Pre-maps codebase symbol relationships so Claude does not burn tokens grepping" -ForegroundColor DarkGray

    Write-Host "`n ------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " BUNDLED SKILLS DIRECTORY:" -ForegroundColor Yellow

    $i = 4
    foreach ($s in $allSkillNames) {
        $skillOn = $true
        if ($cfg.skills -and ($cfg.skills.PSObject.Properties[$s])) {
            $skillOn = [bool]$cfg.skills.$s
        }
        $sColor = if ($skillOn) { "Green" } else { "DarkGray" }
        $sText  = if ($skillOn) { "[ ENABLED  ]" } else { "[ DISABLED ]" }
        $idxStr = if ($i -lt 10) { " [$i] " } else { "[$i] " }
        Write-Host "  $idxStr$($s.PadRight(30)) $sText" -ForegroundColor $sColor
        
        $sub = $skillSubtitles[$s]
        if ($sub) {
            Write-Host "      |-- $sub" -ForegroundColor DarkGray
        }
        $i++
    }

    Write-Host "`n ------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " ACTIONS:" -ForegroundColor Yellow
    Write-Host "  [?] View In-Depth Feature Guide" -ForegroundColor Cyan
    Write-Host "  [T] Run System Diagnostics" -ForegroundColor Green
    Write-Host "  [C] Copy Claude Desktop Instructions to Clipboard" -ForegroundColor White
    Write-Host "  [U] Uninstall Antigravity Suite" -ForegroundColor Red
    Write-Host "  [0] Exit Settings" -ForegroundColor Gray
    Write-Host "==========================================================================" -ForegroundColor Cyan

    Write-Host -NoNewline "`nSelect an option to toggle (0-14, ?, T, C, U): "
    $rawChoice = Read-Host
    if ($rawChoice -eq $null) {
        break
    }
    $choice = $rawChoice.Trim().ToUpper()
    if ([string]::IsNullOrEmpty($choice)) {
        continue
    }

    switch ($choice) {
        "1" { Toggle-Caching $cfg }
        "2" { Toggle-RTK $cfg }
        "3" { 
            Toggle-Graphify $cfg
        }
        "4"  { Toggle-Skill "caveman" $cfg }
        "5"  { Toggle-Skill "session-metrics" $cfg }
        "6"  { Toggle-Skill "session-report" $cfg }
        "7"  { Toggle-Skill "frontend-design" $cfg }
        "8"  { Toggle-Skill "test-driven-development" $cfg }
        "9"  { Toggle-Skill "systematic-debugging" $cfg }
        "10" { Toggle-Skill "verification-before-completion" $cfg }
        "11" { Toggle-Skill "web-artifacts-builder" $cfg }
        "12" { Toggle-Skill "xlsx" $cfg }
        "13" { Toggle-Skill "pdf" $cfg }
        "14" { Toggle-Skill "docx" $cfg }
        "?"  { Show-FeatureGuide }
        "T"  { Run-Diagnostics }
        "C"  { Copy-CustomInstructions }
        "U"  {
            $uninstaller = Join-Path $repoDir "uninstall.bat"
            if (-not (Test-Path $uninstaller)) {
                $uninstaller = Join-Path $binDir "uninstall.bat"
            }
            if (Test-Path $uninstaller) {
                & $uninstaller
            } else {
                Write-Host "Uninstaller script not found." -ForegroundColor Red
            }
            exit
        }
        "0"  { exit }
        default {
            Write-Host "Invalid option. Press any key..." -ForegroundColor Yellow
            Wait-KeyPress
        }
    }
}
